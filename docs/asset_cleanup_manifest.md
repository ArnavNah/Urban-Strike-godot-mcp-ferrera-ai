# Heli-Strike Asset Cleanup & Optimization Audit Manifest

> **Policy Notice:** This manifest is strictly read-only. No files have been deleted. It compares raw pack files with canonical game assets to prepare safe staging for asset pruning.

## Executive Summary

- **Total Asset Files Catalogued:** 1116
- **Total Asset Footprint:** 119.37 MB
- **Actively Referenced Files:** 69
- **Duplicate / Redundant Pack Files:** 751
- **Unreferenced Source Pack Candidates:** 232
- **Preview Thumbnails (Candidate for Build Exclude):** 64

## 1. Redundant Bitwise Duplicates (Exact SHA-256 Collision)

These files are bit-for-bit identical across `assets/source_packs/` and `assets/kenney/`. One copy can safely be archived to reduce project footprint:

| Filename | Size (KB) | Canonical / Referenced Copy | Duplicate Source Copy |
| :--- | :--- | :--- | :--- |
| `colormap.png` | 11.7 | `assets/environment/buildings/Textures/colormap.png` | `assets/environment/industrial/Textures/colormap.png` |
| `variation-a.png` | 11.9 | `assets/environment/buildings/Textures/variation-a.png` | `assets/environment/industrial/Textures/variation-a.png` |
| `variation-b.png` | 11.6 | `assets/environment/buildings/Textures/variation-b.png` | `assets/environment/industrial/Textures/variation-b.png` |
| `variation-c.png` | 12.1 | `assets/environment/buildings/Textures/variation-c.png` | `assets/environment/industrial/Textures/variation-c.png` |
| `planter.glb` | 19.9 | `assets/environment/street_props/planter.glb` | `assets/kenney/City kit suburbann/Models/GLB format/planter.glb` |
| `tree_large.glb` | 5.7 | `assets/environment/vegetation/tree_large.glb` | `assets/kenney/City kit suburbann/Models/GLB format/tree-large.glb` |
| `tree_small.glb` | 5.7 | `assets/environment/vegetation/tree_small.glb` | `assets/kenney/City kit suburbann/Models/GLB format/tree-small.glb` |
| `License.txt` | 0.5 | `assets/kenney/3d_road_tiles/License.txt` | `assets/licenses/LICENSE-Kenney-Road-Tiles.txt` |
| `Preview.png` | 72.9 | `assets/kenney/3d_road_tiles/Preview.png` | `assets/source_packs/kenney_road_tiles/Preview.png` |
| `Sample.png` | 122.4 | `assets/kenney/3d_road_tiles/Sample.png` | `assets/source_packs/kenney_road_tiles/Sample.png` |
| `roadTile_001.gltf` | 3.7 | `assets/kenney/3d_road_tiles/models/roadTile_001.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_001.gltf` |
| `roadTile_002.gltf` | 3.7 | `assets/kenney/3d_road_tiles/models/roadTile_002.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_002.gltf` |
| `roadTile_003.gltf` | 3.7 | `assets/kenney/3d_road_tiles/models/roadTile_003.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_003.gltf` |
| `roadTile_004.gltf` | 3.8 | `assets/kenney/3d_road_tiles/models/roadTile_004.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_004.gltf` |
| `roadTile_005.gltf` | 3.8 | `assets/kenney/3d_road_tiles/models/roadTile_005.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_005.gltf` |
| `roadTile_006.gltf` | 3.8 | `assets/kenney/3d_road_tiles/models/roadTile_006.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_006.gltf` |
| `roadTile_007.gltf` | 3.7 | `assets/kenney/3d_road_tiles/models/roadTile_007.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_007.gltf` |
| `roadTile_008.gltf` | 6.6 | `assets/kenney/3d_road_tiles/models/roadTile_008.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_008.gltf` |
| `roadTile_009.gltf` | 6.6 | `assets/kenney/3d_road_tiles/models/roadTile_009.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_009.gltf` |
| `roadTile_010.gltf` | 7.5 | `assets/kenney/3d_road_tiles/models/roadTile_010.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_010.gltf` |
| `roadTile_011.gltf` | 5.8 | `assets/kenney/3d_road_tiles/models/roadTile_011.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_011.gltf` |
| `roadTile_012.gltf` | 5.8 | `assets/kenney/3d_road_tiles/models/roadTile_012.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_012.gltf` |
| `roadTile_013.gltf` | 8.2 | `assets/kenney/3d_road_tiles/models/roadTile_013.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_013.gltf` |
| `roadTile_014.gltf` | 9.1 | `assets/kenney/3d_road_tiles/models/roadTile_014.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_014.gltf` |
| `roadTile_015.gltf` | 6.8 | `assets/kenney/3d_road_tiles/models/roadTile_015.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_015.gltf` |
| `roadTile_016.gltf` | 7.4 | `assets/kenney/3d_road_tiles/models/roadTile_016.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_016.gltf` |
| `roadTile_017.gltf` | 7.1 | `assets/kenney/3d_road_tiles/models/roadTile_017.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_017.gltf` |
| `roadTile_018.gltf` | 8.4 | `assets/kenney/3d_road_tiles/models/roadTile_018.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_018.gltf` |
| `roadTile_019.gltf` | 9.7 | `assets/kenney/3d_road_tiles/models/roadTile_019.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_019.gltf` |
| `roadTile_020.gltf` | 8.8 | `assets/kenney/3d_road_tiles/models/roadTile_020.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_020.gltf` |
| `roadTile_021.gltf` | 7.5 | `assets/kenney/3d_road_tiles/models/roadTile_021.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_021.gltf` |
| `roadTile_022.gltf` | 7.1 | `assets/kenney/3d_road_tiles/models/roadTile_022.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_022.gltf` |
| `roadTile_023.gltf` | 7.3 | `assets/kenney/3d_road_tiles/models/roadTile_023.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_023.gltf` |
| `roadTile_024.gltf` | 8.1 | `assets/kenney/3d_road_tiles/models/roadTile_024.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_024.gltf` |
| `roadTile_025.gltf` | 10.7 | `assets/kenney/3d_road_tiles/models/roadTile_025.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_025.gltf` |
| `roadTile_026.gltf` | 14.4 | `assets/kenney/3d_road_tiles/models/roadTile_026.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_026.gltf` |
| `roadTile_027.gltf` | 7.5 | `assets/kenney/3d_road_tiles/models/roadTile_027.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_027.gltf` |
| `roadTile_028.gltf` | 6.6 | `assets/kenney/3d_road_tiles/models/roadTile_028.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_028.gltf` |
| `roadTile_029.gltf` | 6.6 | `assets/kenney/3d_road_tiles/models/roadTile_029.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_029.gltf` |
| `roadTile_030.gltf` | 10.4 | `assets/kenney/3d_road_tiles/models/roadTile_030.gltf` | `assets/source_packs/kenney_road_tiles/models/roadTile_030.gltf` |
| *...and 627 more duplicate pairs* | | | |

## 2. Preview Thumbnails & Development Artifacts

Previews in `assets/Previews/` are used only for editor browsing and are not referenced in gameplay scenes:

- Count: 64 images
- Size: 0.12 MB
- Recommended Action: Add `.gdignore` or export filter exclusion so they are excluded from production PCK.

## 3. Top Active Canonical Assets in Production

| Canonical Asset Path | Size (KB) | Type |
| :--- | :--- | :--- |
| `assets/audio/sfx/ui/ui_back.wav` | 6.0 | .WAV |
| `assets/audio/sfx/ui/ui_confirm.wav` | 25.5 | .WAV |
| `assets/audio/sfx/ui/ui_focus.wav` | 10.8 | .WAV |
| `assets/environment/buildings/building_e.glb` | 126.4 | .GLB |
| `assets/environment/buildings/building_l.glb` | 158.6 | .GLB |
| `assets/environment/buildings/building_medium_a.glb` | 173.2 | .GLB |
| `assets/environment/buildings/building_medium_b.glb` | 207.1 | .GLB |
| `assets/environment/buildings/building_medium_f.glb` | 131.8 | .GLB |
| `assets/environment/buildings/building_sawtooth.glb` | 171.7 | .GLB |
| `assets/environment/buildings/building_small_c.glb` | 98.4 | .GLB |
| `assets/environment/buildings/building_small_g.glb` | 104.4 | .GLB |
| `assets/environment/buildings/building_small_j.glb` | 78.9 | .GLB |
| `assets/environment/buildings/building_warehouse_r.glb` | 169.0 | .GLB |
| `assets/environment/buildings/low_detail_building_c.glb` | 12.0 | .GLB |
| `assets/environment/buildings/low_detail_wide_a.glb` | 12.4 | .GLB |
| `assets/environment/buildings/low_detail_wide_b.glb` | 18.3 | .GLB |
| `assets/environment/buildings/skyscraper_a.glb` | 108.7 | .GLB |
| `assets/environment/buildings/skyscraper_b.glb` | 135.2 | .GLB |
| `assets/environment/buildings/skyscraper_c.glb` | 146.0 | .GLB |
| `assets/environment/buildings/skyscraper_d.glb` | 163.2 | .GLB |
| `assets/environment/buildings/skyscraper_e.glb` | 99.5 | .GLB |
| `assets/environment/buildings/Textures/colormap.png` | 11.7 | .PNG |
| `assets/environment/industrial/chimney_large.glb` | 20.4 | .GLB |
| `assets/environment/industrial/chimney_medium.glb` | 14.7 | .GLB |
| `assets/environment/industrial/chimney_small.glb` | 10.3 | .GLB |

## 4. Recommended Pruning Staging Strategy

1. **Phase 1 (Safe Export Filter):** Add `assets/Previews/*` and `assets/source_packs/*` to `.godotignore` or export filters to prevent them from inflating the final binary.
2. **Phase 2 (Canonical Consolidation):** Standardize all road tiles under `assets/kenney/3d_road_tiles/models/` and remove redundant `assets/source_packs/kenney_road_tiles/`.
3. **Phase 3 (Archive):** Move unreferenced suburban FBX/OBJ variations to an external asset vault.
