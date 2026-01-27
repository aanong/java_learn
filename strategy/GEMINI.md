# 策略游戏地图生成规范

## 1. 项目概述

### 1.1 核心目标
生成一张符合古代中国风格的架空世界战争策略游戏地图，兼具艺术美感与游戏实用性。

### 1.2 应用场景
- **策略游戏**: 回合制/即时战略游戏的世界地图
- **叙事背景**: 配合 NovelGen-Enterprise 项目生成的小说世界观
- **桌游辅助**: 可打印的高清地图板

---

## 2. 视觉风格规范

### 2.1 艺术风格
- **主风格**: 古代卷轴 + 水墨画 + 手绘质感
- **色彩方案**: 
  - 主色调: 暖黄色纸张底色 (#F4E8D0)
  - 山脉: 墨绿至深褐渐变 (#2C5F2D → #8B4513)
  - 水系: 青蓝色 (#4A90A4)
  - 边界: 朱红色 (#C8102E)
- **细节要求**: 
  - 边缘做旧效果（撕裂、褶皱、水渍）
  - 装饰性边框（云纹、龙纹、回字纹）
  - 指南针罗盘（八卦或二十四节气样式）

### 2.2 地理真实性
- **地形演化**: 山脉走向符合板块构造学原理
- **水文系统**: 河流从高海拔流向低海拔，支流汇入干流
- **气候分区**: 
  - 北方: 温带大陆性气候（草原、戈壁）
  - 中部: 温带季风气候（平原、丘陵）
  - 南方: 亚热带季风气候（森林、水网）
- **植被分布**: 随纬度和海拔梯度变化

---

## 3. 地图内容规范

### 3.1 政治区划
#### 国家层级
- **大夏** (主角国): 中原核心区域，拥有 8-12 个州
- **大漠汗国** (北方): 草原与戈壁，3-5 个部落联盟
- **大越国** (南方): 山地与水网，5-7 个州
- **未解锁区域**: 迷雾覆盖，标注"未知之地"

#### 州县命名规则
| 层级 | 命名风格 | 示例 |
|------|----------|------|
| 州 | 方位/地貌/古意 | 云州、青州、玄州、凌州、霜州 |
| 县 | 自然景观/神话元素 | 凤鸣县、白鹿县、苍岩县、落霞县 |
| 城镇 | 战略地位/历史典故 | 龙门城、鹰扬镇、赤壁关、虎牢关 |

### 3.2 地形要素
#### 必须包含的地形类型
- **山脉**: 3-5 条主要山脉（如"苍龙山脉"、"天柱山"）
- **河流**: 2-3 条大河（如"青江"、"玄水"）
- **湖泊**: 5-8 个大型湖泊
- **平原**: 适合农业的核心区域
- **森林**: 南方密林、北方疏林
- **沙漠/戈壁**: 西北边境
- **草原**: 北方游牧区

#### 战略要素
- **关隘**: 山脉隘口（标注"险"字）
- **要塞**: 边境重镇（城墙图标）
- **商道**: 虚线标注贸易路线
- **渡口**: 重要河流交叉点

---

## 4. 技术实现规范

### 4.1 生成工具选择
**推荐工具链**:
1. **AI 图像生成**: 
   - 主力: Midjourney v6 / DALL-E 3
   - 备选: Stable Diffusion XL (本地部署)
2. **后期处理**: 
   - Photoshop (图层分离、细节优化)
   - GIMP (开源替代方案)
3. **矢量化**: 
   - Illustrator (地名标注、边界线)
   - Inkscape (开源替代方案)

### 4.2 AI 生成 Prompt 模板
```
A highly detailed fantasy map in ancient Chinese scroll style, depicting a fictional continent for a strategy game. 

VISUAL STYLE:
- Hand-drawn aesthetic with ink wash painting techniques
- Aged parchment background (#F4E8D0) with weathered edges
- Decorative border featuring cloud patterns and dragon motifs
- Compass rose in traditional Chinese bagua (八卦) style

GEOGRAPHY:
- 3 major mountain ranges (dark green to brown gradients)
- 2 large rivers flowing from mountains to sea (blue #4A90A4)
- 6 lakes of varying sizes
- Diverse terrain: plains, forests, deserts, grasslands
- Realistic topography following plate tectonics principles

POLITICAL DIVISIONS:
- Central empire "大夏" with 10 provinces (州) marked in red borders
- Northern nomadic confederation "大漠汗国" in grasslands
- Southern kingdom "大越国" in forested mountains
- Province names in elegant Chinese calligraphy

STRATEGIC ELEMENTS:
- Mountain passes marked with "关" (pass)
- Fortified cities with wall icons
- Trade routes as dotted lines
- River crossings at strategic points

TECHNICAL SPECS:
- Resolution: 4096x4096 pixels
- Style: Epic, historical, cartographic
- Lighting: Soft, even illumination as if lit by candlelight
- Details: High level of granularity for place names and terrain features

--ar 1:1 --v 6 --style raw --s 250
```

### 4.3 输出格式规范

#### 主图文件
| 格式 | 用途 | 规格 |
|------|------|------|
| **PNG** | 游戏展示/打印 | 4096x4096, 300 DPI, 无损压缩 |
| **JPEG** | 网页预览 | 2048x2048, 150 DPI, 质量 90% |
| **TIFF** | 专业印刷 | 8192x8192, 600 DPI, LZW 压缩 |

#### 图层分离文件 (PSD/XCF)
```
地图项目.psd
├── Layer 1: 背景纸张纹理
├── Layer 2: 地形底图（山脉、平原、沙漠）
├── Layer 3: 水系（河流、湖泊、海洋）
├── Layer 4: 植被（森林、草原）
├── Layer 5: 政治边界（国界、州界）
├── Layer 6: 地名标注（国名、州名、县名）
├── Layer 7: 战略标记（关隘、要塞、商道）
└── Layer 8: 装饰边框与罗盘
```

#### 数据文件 (GeoJSON)
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [2048, 1024]
      },
      "properties": {
        "name": "龙门城",
        "type": "city",
        "province": "云州",
        "country": "大夏",
        "strategic_value": 9,
        "terrain": "mountain_pass"
      }
    }
  ]
}
```

---

## 5. 游戏引擎集成

### 5.1 Unity 集成方案
#### Tilemap 切片
```bash
# 使用 ImageMagick 切割为 256x256 瓦片
magick convert map_4k.png -crop 256x256 +repage tiles/tile_%04d.png
```

#### 导入配置
```csharp
// Unity Tilemap 设置
Tilemap tilemap = GetComponent<Tilemap>();
tilemap.tileAnchor = new Vector3(0.5f, 0.5f, 0);
tilemap.orientation = Tilemap.Orientation.XY;

// 加载地理数据
TextAsset geoData = Resources.Load<TextAsset>("world_manifest");
WorldData world = JsonUtility.FromJson<WorldData>(geoData.text);
```

### 5.2 Unreal Engine 集成方案
#### Landscape 高度图
```python
# 从地形图生成高度图
from PIL import Image
import numpy as np

terrain = Image.open('map_terrain_layer.png').convert('L')
heightmap = np.array(terrain)
# 归一化到 16-bit
heightmap_16bit = (heightmap / 255.0 * 65535).astype(np.uint16)
Image.fromarray(heightmap_16bit).save('landscape_heightmap.raw')
```

#### 材质分区
- **Landscape Layer**: 根据地形类型自动混合材质
  - 平原: 草地材质
  - 山地: 岩石材质
  - 水系: 水体着色器

---

## 6. 质量验收标准

### 6.1 视觉质量
- [ ] 整体风格统一，无现代元素混入
- [ ] 地名清晰可读（最小字号 ≥ 12pt）
- [ ] 色彩对比度符合 WCAG AA 标准（对比度 ≥ 4.5:1）
- [ ] 边框装饰精美，无明显 AI 生成瑕疵

### 6.2 地理合理性
- [ ] 河流流向符合重力原理（无上坡水）
- [ ] 气候分布与纬度/地形相符
- [ ] 山脉走向连贯，无孤立山峰
- [ ] 城市分布合理（靠近水源/平原）

### 6.3 游戏可用性
- [ ] 战略要地分布均衡（每个国家至少 3 个关隘）
- [ ] 资源点暗示明确（森林=木材，山脉=矿产）
- [ ] 可导航路径清晰（陆路/水路）
- [ ] 迷雾区域预留扩展空间

### 6.4 技术规格
- [ ] 主图分辨率 ≥ 4096x4096
- [ ] 文件大小 ≤ 50MB (PNG)
- [ ] GeoJSON 数据完整（所有城市/关隘已标注）
- [ ] 图层文件可编辑（PSD 未合并图层）

---

## 7. 迭代优化流程

### 第一版: 基础地形生成
1. 使用 AI 生成基础地形图
2. 人工审核地理合理性
3. 调整山脉/河流走向

### 第二版: 政治区划标注
1. 在 Illustrator 中绘制边界线
2. 添加国名/州名标注
3. 标注战略要地

### 第三版: 细节优化
1. 添加装饰边框
2. 优化色彩平衡
3. 增加做旧效果

### 第四版: 数据导出
1. 分离图层并导出 PSD
2. 生成 GeoJSON 数据文件
3. 切割瓦片地图（如需要）

---

## 8. 与 NovelGen-Enterprise 的协同

### 数据同步规则
- **地名一致性**: 小说中提到的地名必须在地图上存在
- **距离校验**: 小说中的行程时间应与地图距离匹配
- **气候描写**: 小说场景的气候应符合地图的气候分区

### 自动化脚本
```python
# 从地图数据生成小说世界观配置
import json

with open('geo/world_manifest.json') as f:
    world_data = json.load(f)

novel_bible = {
    "world_name": world_data["world_name"],
    "countries": [c["name"] for c in world_data["countries"]],
    "major_cities": [city for country in world_data["countries"] 
                     for city in country["major_cities"]],
    "climate_zones": world_data["climate_zones"]
}

# 导入到 NovelGen 数据库
# INSERT INTO novel_bible (world_config) VALUES (novel_bible)
```

---

## 9. 示例 Prompt (完整版)

### For Midjourney
```
Ancient Chinese fantasy world map, strategy game cartography, hand-drawn scroll style --ar 1:1 --v 6

COMPOSITION:
- Central empire "大夏" (10 provinces) in fertile plains
- Northern steppes "大漠汗国" with nomadic territories  
- Southern mountains "大越国" with dense forests
- Unexplored fog-covered regions at map edges

TERRAIN DETAILS:
- 苍龙山脉 (Azure Dragon Range): Massive mountains running east-west
- 青江 (Azure River): Major river from mountains to eastern sea
- 玄水 (Mystic Waters): Southern river system with tributaries
- 天池 (Celestial Lake): Large central lake, strategic water source

ARTISTIC STYLE:
- Ink wash painting techniques (山水画)
- Aged parchment texture with torn edges
- Decorative border: intertwined dragons and clouds
- Calligraphic place names in seal script (篆书)
- Compass rose: traditional Chinese 八卦 (bagua) design
- Color palette: sepia tones, forest green, river blue, vermillion borders

STRATEGIC MARKERS:
- 🏰 Fortified cities (城): thick wall icons
- ⛰️ Mountain passes (关): red "关" character
- 🛤️ Trade routes (商道): dotted gold lines
- ⚔️ Battlefields (古战场): crossed swords icon

TECHNICAL:
- Ultra high resolution, 4K quality
- Even lighting, no harsh shadows
- Legible text at all zoom levels
- Print-ready, 300 DPI equivalent

--style raw --s 250 --q 2
```

---

## 10. 附录: 参考资源

### 历史地图参考
- 《禹贡地域图》(中国古代地理)
- 《坤舆万国全图》(明代世界地图)
- 《皇舆全览图》(清代精密地图)

### 游戏地图范例
- 《全面战争:三国》世界地图
- 《十字军之王3》地图系统
- 《文明6》地形生成算法

### 技术文档
- [Unity Tilemap 官方文档](https://docs.unity3d.com/Manual/Tilemap.html)
- [Unreal Landscape 教程](https://docs.unrealengine.com/5.0/en-US/landscape-technical-guide/)
- [GeoJSON 规范](https://geojson.org/)