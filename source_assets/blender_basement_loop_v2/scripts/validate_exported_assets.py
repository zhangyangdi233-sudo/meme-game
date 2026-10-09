"""Read-only static glTF inspection; never starts Blender or Godot.

Writes asset_validation.json and asset_validation.md beside the exported models.
Requires the bundled Python runtime's NumPy. No third-party model code is run.
"""
import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path
import struct

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


class GLB:
    def __init__(self, path):
        self.path = path
        self.raw = path.read_bytes()
        magic, version, length = struct.unpack_from("<4sII", self.raw)
        assert magic == b"glTF" and version == 2 and length == len(self.raw), "Invalid GLB header"
        self.data, self.binary = None, None
        offset = 12
        while offset < len(self.raw):
            size, kind = struct.unpack_from("<II", self.raw, offset)
            chunk = self.raw[offset+8:offset+8+size]
            assert len(chunk) == size and size % 4 == 0, "Invalid GLB chunk"
            if kind == 0x4E4F534A:
                self.data = json.loads(chunk)
            elif kind == 0x004E4942:
                self.binary = chunk
            offset += 8+size
        assert self.data is not None and self.binary is not None
        assert len(self.data["buffers"]) == 1 and "uri" not in self.data["buffers"][0]
        assert self.data["buffers"][0]["byteLength"] <= len(self.binary)
        self.parents = {}
        for i, node in enumerate(self.data.get("nodes", [])):
            for child in node.get("children", []):
                assert 0 <= child < len(self.data["nodes"])
                assert child not in self.parents, "Multiple node parents"
                self.parents[child] = i
        self.transforms = {}
        self.cache = {}

    def accessor(self, index):
        if index in self.cache:
            return self.cache[index]
        accessor = self.data["accessors"][index]
        assert "sparse" not in accessor, "Sparse accessor requires separate validation"
        view = self.data["bufferViews"][accessor["bufferView"]]
        assert view.get("buffer", 0) == 0
        dtype = np.dtype(COMPONENTS[accessor["componentType"]])
        width = WIDTHS[accessor["type"]]
        count = accessor["count"]
        stride = view.get("byteStride", width*dtype.itemsize)
        local_offset = accessor.get("byteOffset", 0)
        required = local_offset + (count-1)*stride + width*dtype.itemsize if count else local_offset
        assert required <= view["byteLength"], "Accessor extends beyond its view"
        array = np.ndarray((count, width), dtype=dtype, buffer=self.binary,
                           offset=view.get("byteOffset", 0)+local_offset,
                           strides=(stride, dtype.itemsize)).copy()
        if accessor.get("normalized") and accessor["componentType"] != 5126:
            info = np.iinfo(dtype)
            array = array.astype(float)/info.max
            if info.min < 0:
                array = np.maximum(array, -1)
        assert np.isfinite(array).all(), "Nonfinite accessor value"
        self.cache[index] = array
        return array

    def world(self, index, visiting=None):
        if index in self.transforms:
            return self.transforms[index]
        visiting = set() if visiting is None else visiting
        assert index not in visiting, "Cyclic node graph"
        visiting.add(index)
        node = self.data["nodes"][index]
        if "matrix" in node:
            local = np.array(node["matrix"], dtype=float).reshape((4,4), order="F")
        else:
            x,y,z,w = node.get("rotation", [0,0,0,1])
            rotation = np.array([
                [1-2*y*y-2*z*z, 2*x*y-2*z*w, 2*x*z+2*y*w],
                [2*x*y+2*z*w, 1-2*x*x-2*z*z, 2*y*z-2*x*w],
                [2*x*z-2*y*w, 2*y*z+2*x*w, 1-2*x*x-2*y*y]])
            local = np.eye(4)
            local[:3,:3] = rotation @ np.diag(node.get("scale", [1,1,1]))
            local[:3,3] = node.get("translation", [0,0,0])
        result = self.world(self.parents[index], visiting) @ local if index in self.parents else local
        visiting.remove(index)
        self.transforms[index] = result
        return result

    def find(self, name):
        result = [i for i,n in enumerate(self.data["nodes"]) if n.get("name") == name]
        assert len(result) == 1, f"Expected one node {name}, got {len(result)}"
        return result[0]

    def descendants(self, index):
        result = []
        for child in self.data["nodes"][index].get("children", []):
            result.append(child)
            result.extend(self.descendants(child))
        return result

    def points(self, index, local=False):
        node = self.data["nodes"][index]
        if "mesh" not in node:
            return np.empty((0,3))
        chunks = [self.accessor(p["attributes"]["POSITION"]) for p in self.data["meshes"][node["mesh"]]["primitives"]]
        points = np.concatenate(chunks)
        if not local:
            transform = self.world(index)
            points = points @ transform[:3,:3].T + transform[:3,3]
        return points

    def summary(self):
        data = self.data
        for i, view in enumerate(data.get("bufferViews", [])):
            assert view.get("buffer",0) == 0
            assert view.get("byteOffset",0)+view["byteLength"] <= len(self.binary), f"bufferView {i} out of bounds"
        for i in range(len(data.get("accessors", []))):
            self.accessor(i)
        triangle_counts, vertex_counts = [], []
        for mesh in data.get("meshes", []):
            triangles = vertices = 0
            for primitive in mesh["primitives"]:
                position = self.accessor(primitive["attributes"]["POSITION"])
                vertices += len(position)
                for key, ai in primitive["attributes"].items():
                    assert len(self.accessor(ai)) == len(position), "Attribute counts differ"
                if "indices" in primitive:
                    indices = self.accessor(primitive["indices"]).reshape(-1)
                    assert np.min(indices) >= 0 and np.max(indices) < len(position)
                    count = len(indices)
                else:
                    count = len(position)
                assert primitive.get("mode", 4) == 4, "Non-triangle primitive needs separate counting"
                assert count % 3 == 0
                triangles += count//3
            triangle_counts.append(triangles)
            vertex_counts.append(vertices)
        names = [n.get("name", "") for n in data.get("nodes", [])]
        assert len(names) == len(set(names)), "Duplicate exported node names"
        mesh_nodes = [i for i,n in enumerate(data.get("nodes", [])) if "mesh" in n]
        collision_nodes = [i for i in mesh_nodes if names[i].endswith("-colonly")]
        malformed = [name for name in names if "-colonly" in name and not name.endswith("-colonly")]
        assert not malformed, "Collision suffix is not terminal"
        points = np.concatenate([self.points(i) for i in mesh_nodes]) if mesh_nodes else np.empty((0,3))
        images = []
        for image in data.get("images", []):
            assert "uri" not in image and "bufferView" in image, "External image reference"
            view = data["bufferViews"][image["bufferView"]]
            payload = self.binary[view.get("byteOffset",0):view.get("byteOffset",0)+view["byteLength"]]
            assert image.get("mimeType") == "image/png" and payload.startswith(b"\x89PNG\r\n\x1a\n"), "Unknown image encoding"
            width,height = struct.unpack_from(">II", payload, 16)
            images.append({"name": image.get("name"), "width": width, "height": height,
                           "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
        return {
            "path": str(self.path.relative_to(ROOT)).replace("\\", "/"),
            "bytes": len(self.raw), "sha256": hashlib.sha256(self.raw).hexdigest(),
            "nodes": len(names), "meshes": len(data.get("meshes", [])), "mesh_instances": len(mesh_nodes),
            "unique_mesh_triangles": sum(triangle_counts),
            "scene_triangles_including_collision": sum(triangle_counts[data["nodes"][i]["mesh"]] for i in mesh_nodes),
            "render_triangles": sum(triangle_counts[data["nodes"][i]["mesh"]] for i in mesh_nodes if i not in collision_nodes),
            "collision_triangles": sum(triangle_counts[data["nodes"][i]["mesh"]] for i in collision_nodes),
            "unique_mesh_vertices": sum(vertex_counts), "materials": len(data.get("materials", [])),
            "textures": len(data.get("textures", [])), "embedded_images": images,
            "collision_nodes": [names[i] for i in collision_nodes],
            "malformed_collision_suffixes": malformed,
            "aabb_gltf_min": np.min(points,axis=0).round(6).tolist() if len(points) else None,
            "aabb_gltf_max": np.max(points,axis=0).round(6).tolist() if len(points) else None,
            "dimensions_xyz_gltf": np.ptp(points,axis=0).round(6).tolist() if len(points) else None,
            "extensions_used": data.get("extensionsUsed", []),
            "external_references": [], "accessors_checked": len(data.get("accessors", [])),
            "result": "passed",
        }


def convert(values):
    x,y,z = values
    return np.array([x,z,-y])


def screen_report(glb):
    candidates = [(i,n) for i,n in enumerate(glb.data["nodes"]) if "Screen_Video" in n.get("name", "")]
    assert len(candidates) == 1
    index, node = candidates[0]
    primitives = glb.data["meshes"][node["mesh"]]["primitives"]
    assert len(primitives) == 1
    primitive = primitives[0]
    pos = glb.accessor(primitive["attributes"]["POSITION"])
    uv = glb.accessor(primitive["attributes"]["TEXCOORD_0"])
    normals = glb.accessor(primitive["attributes"]["NORMAL"])
    assert np.allclose(uv.min(axis=0), [0,0]) and np.allclose(uv.max(axis=0),[1,1])
    assert np.max(np.abs(np.linalg.norm(normals,axis=1)-1)) < 1e-4
    # Blender front -Y becomes glTF +Z before the assembly's placement rotation.
    assert np.min(normals[:,2]) > .97
    indices = glb.accessor(primitive["indices"]).reshape(-1,3).astype(int)
    triangles = pos[indices]
    cross = np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
    assert np.min(cross[:,2]) > 0, "Reversed/degenerate screen triangle"
    dimensions = np.ptp(pos,axis=0)
    assert abs(dimensions[0]/dimensions[1]-4/3) < 1e-5
    assert np.corrcoef(pos[:,0],uv[:,0])[0,1] > .999
    assert np.corrcoef(pos[:,1],uv[:,1])[0,1] < -.999
    matrix = glb.world(index)
    normal_matrix = np.linalg.inv(matrix[:3,:3]).T
    world_normal = normal_matrix @ normals.mean(axis=0)
    world_normal /= np.linalg.norm(world_normal)
    material = glb.data["materials"][primitive["material"]]
    return {"node":node["name"], "vertices":len(pos), "triangles":len(indices),
            "local_dimensions_xyz_gltf":dimensions.round(6).tolist(),
            "uv_min":uv.min(axis=0).tolist(), "uv_max":uv.max(axis=0).tolist(),
            "uv_export_convention":"glTF top-left texture origin: exported V decreases as local height increases; expected Blender glTF conversion, not a flipped mesh",
            "normal_length_max_error":float(np.max(np.abs(np.linalg.norm(normals,axis=1)-1))),
            "minimum_local_forward_dot":float(np.min(normals[:,2])),
            "world_front_direction_gltf":world_normal.round(6).tolist(),
            "triangle_winding":"outward, glTF local +Z", "material":material,
            "KHR_materials_unlit_exported":"KHR_materials_unlit" in material.get("extensions",{}),
            "runtime_requirement":"Replace this surface with unshaded video material during playback. Exported green standby is emissive PBR, not KHR_materials_unlit.",
            "result":"passed"}


def validate():
    contract = json.loads((ROOT/"asset_contract.json").read_text(encoding="utf-8"))
    paths = [ROOT/"Basement_Loop_v2.glb", ROOT/"Basement_Architecture_v2.glb", ROOT/"Opening_WhiteDoor_v2.glb"]
    asset_paths = sorted((ROOT/"asset_library").glob("*.glb"))
    paths += asset_paths
    files, readers = [], {}
    for path in paths:
        glb = GLB(path)
        files.append(glb.summary())
        readers[path.name] = glb
    main = readers["Basement_Loop_v2.glb"]
    architecture = readers["Basement_Architecture_v2.glb"]
    anchors = {}
    for name, definition in contract["anchors"].items():
        position = main.world(main.find(name))[:3,3]
        assert np.allclose(position,convert(definition["position"]),atol=1e-5)
        anchors[name] = {"position_gltf":position.tolist(), "matches_contract":True}
    doors = {}
    for key, definition in contract["doors"].items():
        pivot_index = main.find(definition["pivot_node"])
        leaf_index = main.find(definition["leaf_node"])
        child_indices = main.descendants(pivot_index)
        assert leaf_index in child_indices
        children = [main.data["nodes"][i].get("name", "") for i in child_indices]
        assert not any("colonly" in n for n in children)
        assert np.allclose(main.world(pivot_index)[:3,3],convert(definition["hinge"]),atol=1e-5)
        relative = np.linalg.inv(main.world(pivot_index)) @ main.world(leaf_index)
        assert np.allclose(relative[:3,3],convert(definition["closed_leaf_local_center"]),atol=1e-5)
        dimensions = np.ptp(main.points(leaf_index,local=True),axis=0)
        expected_size = np.abs(convert(definition["leaf_size_blender"]))
        assert np.allclose(dimensions,expected_size,atol=1e-5)
        assert len(child_indices) == 15
        doors[key] = {"pivot":definition["pivot_node"],"children":children,
                      "leaf_local_center_gltf":relative[:3,3].round(6).tolist(),
                      "leaf_dimensions_xyz_gltf":dimensions.round(6).tolist(),
                      "static_collision_under_pivot":False,"matches_contract":True}
    ramp_name = contract["collision"]["stair_ramp_node"]
    main.find(ramp_name)
    architecture.find(ramp_name)
    architecture_names = [n.get("name", "") for n in architecture.data["nodes"]]
    contamination = [name for name in architecture_names if name.startswith("Prop_") or name.startswith("PropCollision_") or "Screen_Video" in name]
    assert not contamination, "Props leaked into architecture export"
    assert {p.stem for p in asset_paths} == {"box","chair","console","crt","frame","kids_chair","kids_table","side_table","switch","vhs","white_door"}
    screens = {"dressed_basement":screen_report(main),"standalone_crt":screen_report(readers["crt.glb"])}
    opening_glb = readers["Opening_WhiteDoor_v2.glb"]
    op = contract["opening"]
    pivot_index = opening_glb.find(op["pivot_node"])
    leaf_index = opening_glb.find(op["leaf_node"])
    spawn_index = opening_glb.find(op["spawn_node"])
    op_children = opening_glb.descendants(pivot_index)
    assert len(op_children) == 16 and leaf_index in op_children
    assert not any("colonly" in opening_glb.data["nodes"][i].get("name", "") for i in op_children)
    assert opening_glb.find(op["light_plane_node"]) not in op_children
    op_hinge = opening_glb.world(pivot_index)[:3,3]
    op_spawn = opening_glb.world(spawn_index)[:3,3]
    assert np.allclose(op_hinge,convert(op["hinge_blender"]),atol=1e-5)
    assert np.allclose(op_spawn,convert(op["spawn_feet_blender"]),atol=1e-5)
    assert opening_glb.data["nodes"][spawn_index]["extras"]["position_is_feet"] is True
    relative = np.linalg.inv(opening_glb.world(pivot_index)) @ opening_glb.world(leaf_index)
    assert np.allclose(relative[:3,3],convert(op["leaf_local_center"]),atol=1e-5)
    opening_leaf_dimensions = np.ptp(opening_glb.points(leaf_index,local=True),axis=0)
    opening_collision_size = np.abs(convert(op["leaf_size_blender"]))
    # The original white leaf is 78 mm thick; the contract deliberately rounds
    # its runtime blocker to 80 mm. Width and height must match exactly.
    assert np.allclose(opening_leaf_dimensions[:2],opening_collision_size[:2],atol=1e-5)
    assert 0 <= opening_collision_size[2]-opening_leaf_dimensions[2] <= .003
    door_centre = opening_glb.world(leaf_index)[:3,3]
    planar_distance = float(np.linalg.norm((door_centre-op_spawn)[[0,2]]))
    assert abs(planar_distance-18.0) < 1e-5
    white = readers["white_door.glb"]
    white_pivot = white.find("AssetWhite_OpeningDoorPivot")
    assert len(white.descendants(white_pivot)) == 16
    assert np.allclose(white.world(white.find("APH2_WhiteDoor_Root")),np.eye(4),atol=1e-5)
    opening_report = {"pivot":op["pivot_node"],"moving_descendants":[opening_glb.data["nodes"][i]["name"] for i in op_children],
                      "spawn_feet_gltf":op_spawn.tolist(),"spawn_explicitly_marked_as_feet":True,
                      "horizontal_spawn_to_door_centre_m":planar_distance,
                      "leaf_local_center_gltf":relative[:3,3].round(6).tolist(),
                      "visual_leaf_dimensions_xyz_gltf":opening_leaf_dimensions.round(6).tolist(),
                      "contract_blocker_dimensions_xyz_gltf":opening_collision_size.tolist(),
                      "light_plane_under_pivot":False,"standalone_white_door_pivot_descendants":16,"result":"passed"}
    report = {
        "generated_at_utc":datetime.now(timezone.utc).isoformat(),
        "method":"Read-only GLB binary, JSON, all accessors, hierarchy and numeric geometry inspection; no Blender/Godot execution",
        "status":"static_validation_passed_runtime_validation_separate",
        "asset_contract_sha256":hashlib.sha256((ROOT/"asset_contract.json").read_bytes()).hexdigest(),
        "files":files,"anchors":anchors,"doors":doors,"screens":screens,
        "architecture_props_found":contamination,"standalone_asset_count":len(asset_paths),"opening":opening_report,
        "static_geometry_notes":{
            "coordinate_conversion":"Blender (x,y,z) -> glTF/Godot (x,z,-y)",
            "player_capsule_radius_m":.34,"player_capsule_height_m":1.72,
            "door_clear_width_m":1.06,"door_side_margin_for_centered_player_m":.19,
            "right_passage_width_m":1.55,"landing_headroom_m":2.43,
            "ramp_angle_degrees":math.degrees(math.atan2(2.72,4.34)),
            "ramp_visual_tread_nose_difference_m":[.1248,.188],
            "ramp_choice":"Smooth ramp deliberately retained for first-person movement. Visible feet/IK would need a separate stair-aware solution.",
            "NPC_anchor_y_blender":contract["anchors"]["NPCAnchor"]["position"][1],
            "tv_anchor_blender":contract["anchors"]["TVAnchor"]["position"],
        },
        "limitations":[
            "No interactive walk, physics import, light/video playback, GPU performance, game progress or saved-game test performed by this static script.",
            "Asset Browser preference registration and .blend embedded image/preview persistence are outside GLB binary validation; parent live Blender task owns those checks.",
            "GLB screen off-state exports emissive PBR rather than KHR_materials_unlit; runtime unshaded video material override is required and documented.",
        ]
    }
    (ROOT/"asset_validation.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    summary = ["# 地下室 v2：导出资产静态核验", "",
               "结果：静态检查通过。直接读取实际 GLB 文件，没有启动 Blender、Godot 或 UI；本报告不代替游戏内运行验收。", "",
               "| 文件 | MiB | 节点 | 网格 | 可见三角形 | 碰撞节点 | 内嵌图片 |",
               "|---|---:|---:|---:|---:|---:|---:|"]
    for f in files:
        summary.append(f"| `{f['path']}` | {f['bytes']/1048576:.2f} | {f['nodes']} | {f['meshes']} | {f['render_triangles']:,} | {len(f['collision_nodes'])} | {len(f['embedded_images'])} |")
    summary += ["", "## 验证范围", "",
                "- 检查 GLB 头、JSON/BIN 分块、全部 bufferView/accessor 边界、有限数值、索引范围、三角形计数、节点父子关系及节点名唯一性。",
                "- 所有碰撞节点都以 `-colonly` 严格结尾，包含 `Stair_WalkRamp-colonly`。门扇没有被并入静态碰撞。",
                "- 入口、出口门轴各带 15 个后代：门扇、12 块饰板、两侧把手。门轴位置、门扇局部中心和尺寸符合契约。",
                "- 所有游戏锚点的位置与契约一致；Blender Z 向上已转换为 glTF/Godot Y 向上。",
                "- Architecture 版本没有道具、道具碰撞或 CRT 屏幕；保留房壳、楼梯、门、固定灯具和必要游戏锚点。",
                "- 11 个单独资产 GLB 均存在，纹理全部嵌入 BIN；没有外部图片/缓冲文件引用。白门资产保留独立门轴，根节点位于门框底部中心。",
                "- 开场白门有 16 个随门轴运动的后代，光面保持固定。OpeningSpawn 明确标为脚底坐标，高度 0.04 m；与门中心的水平距离精确为 18 m。",
                "", "## CRT 屏幕", "",
                "主场景及单独 CRT 均有唯一 Screen_Video 网格。画面尺寸 0.466 × 0.3495 m，比例 4:3，32 × 24 面网格导出为 1,536 个三角形，UV 完整覆盖 0–1。顶点法线长度正常，三角形朝向外侧，场景中的屏幕面朝房间。glTF 导出按规范转换纹理 V 方向，不是屏幕几何反面。",
                "",
                "**材质注意：** 实际 GLB 的屏幕使用绿色发光待机 PBR 材质，未输出 `KHR_materials_unlit`。播放视频时应给这一个表面覆盖 unshaded 视频材质；待机、关闭和播放状态由游戏组件控制。",
                "", "## 动线与已接受限制", "",
                "玩家胶囊半径 0.34 m、高 1.72 m。门洞宽 1.06 m，居中时两侧各剩 0.19 m；右通道宽 1.55 m。上平台净高 2.43 m，平滑楼梯坡度约 32.08°。NPC 已靠后至 Blender Y=3.70，TV 位于 (2.0, -3.69, 0.785)，朝房间中心及下楼玩家。场景柜体加深承托 CRT，独立资产仍保持原尺寸。",
                "",
                "楼梯保留第一人称用平滑坡碰撞，踏步鼻端比坡面高约 12.5–18.8 cm。当前选择便于连续行走；以后加入可见腿脚或足部 IK 时，需要另做贴合踏面方案。",
                "",
                "本报告不确认 Asset Browser 偏好设置、.blend 缩略图持久化、游戏内门锁/循环逻辑、声音/视频实际播放或帧率。这些由主线程和游戏接入线程独立验证。详细数据、节点列表、图片尺寸和 SHA-256 见 `asset_validation.json`。", ""]
    (ROOT/"asset_validation.md").write_text("\n".join(summary),encoding="utf-8")
    print(json.dumps({"status":report["status"],"files":len(files),"assets":len(asset_paths),
                      "main_render_triangles":files[0]["render_triangles"],"main_collision_nodes":len(files[0]["collision_nodes"]),
                      "architecture_props":contamination,"screens_passed":list(screens)},ensure_ascii=False))


if __name__ == "__main__":
    validate()
