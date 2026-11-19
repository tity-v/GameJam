# 从《过去的你》导出包恢复出的第一关数据（反编译参考，仅读取）
# 来源: _unpack/recovered/scripts/platformer/levels.gd  (build(0))
LEVEL_NAME = "第一次留下自己"
LEVEL_HINT = "走到压力板并等待一会儿，再按 E；下一轮趁回声压板时穿门。"
SPAWN = (90, 522)
WIDTH = 1600.0
SOLIDS = [
    (-40, 560, 1800, 120),   # 地面
    (-40, 0, 40, 680),       # 左墙
]
PLATES = [(390, 548, 75, 12)]
DOORS = [(790, 390, 30, 170)]
SPIKES = []
MOVING = []
BOXES = []
EXIT = (1370, 495, 52, 65)
NEEDS = 1

# 外观规格，来自 main.gd 的 _draw()
BG = (16, 23, 32)                 # 101720
SOLID_FILL = (64, 88, 95)         # 40585f
SOLID_TOP = (131, 166, 165)       # 83a6a5, 顶边线宽 3
PLATE_OFF = (129, 144, 146)       # 819092
PLATE_ON = (117, 232, 189)        # 75e8bd (激活态，静态场景用未激活)
DOOR = (213, 169, 116)            # d5a974
SPIKE = (231, 122, 113)           # e77a71
EXIT_BORDER = (123, 227, 185)     # 7be3b9, 宽 3
EXIT_FILL = (92, 230, 171, 46)    # (0.36,0.9,0.67,0.18)
GRID = (0.4, 0.7, 0.7, 0.04)
GRID_STEP = 80
GRID_TOP = 100
VIEWPORT = (1280, 720)
