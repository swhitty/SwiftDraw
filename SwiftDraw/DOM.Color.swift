//
//  DOM.Color.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 31/12/16.
//  Copyright 2020 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

extension DOM {
  
  enum Color: Equatable {
    case none
    case keyword(Keyword)
    case rgbi(UInt8, UInt8, UInt8)
    case rgbf(DOM.Float, DOM.Float, DOM.Float)
    case p3(DOM.Float, DOM.Float, DOM.Float)
    case hex(UInt8, UInt8, UInt8)

    // see: https://www.w3.org/TR/SVG11/types.html#ColorKeywords
    enum Keyword: String {
      case aliceblue
      case antiquewhite
      case aqua
      case aquamarine
      case azure
      case beige
      case bisque
      case black
      case blanchedalmond
      case blue
      case blueviolet
      case brown
      case burlywood
      case cadetblue
      case chartreuse
      case chocolate
      case coral
      case cornflowerblue
      case cornsilk
      case crimson
      case cyan
      case darkblue
      case darkcyan
      case darkgoldenrod
      case darkgray
      case darkgreen
      case darkgrey
      case darkkhaki
      case darkmagenta
      case darkolivegreen
      case darkorange
      case darkorchid
      case darkred
      case darksalmon
      case darkseagreen
      case darkslateblue
      case darkslategray
      case darkslategrey
      case darkturquoise
      case darkviolet
      case deeppink
      case deepskyblue
      case dimgray
      case dimgrey
      case dodgerblue
      case firebrick
      case floralwhite
      case forestgreen
      case fuchsia
      case gainsboro
      case ghostwhite
      case gold
      case goldenrod
      case gray
      case grey
      case green
      case greenyellow
      case honeydew
      case hotpink
      case indianred
      case indigo
      case ivory
      case khaki
      case lavender
      case lavenderblush
      case lawngreen
      case lemonchiffon
      case lightblue
      case lightcoral
      case lightcyan
      case lightgoldenrodyellow
      case lightgray
      case lightgreen
      case lightgrey
      case lightpink
      case lightsalmon
      case lightseagreen
      case lightskyblue
      case lightslategray
      case lightslategrey
      case lightsteelblue
      case lightyellow
      case lime
      case limegreen
      case linen
      case magenta
      case maroon
      case mediumaquamarine
      case mediumblue
      case mediumorchid
      case mediumpurple
      case mediumseagreen
      case mediumslateblue
      case mediumspringgreen
      case mediumturquoise
      case mediumvioletred
      case midnightblue
      case mintcream
      case mistyrose
      case moccasin
      case navajowhite
      case navy
      case oldlace
      case olive
      case olivedrab
      case orange
      case orangered
      case orchid
      case palegoldenrod
      case palegreen
      case paleturquoise
      case palevioletred
      case papayawhip
      case peachpuff
      case peru
      case pink
      case plum
      case powderblue
      case purple
      case red
      case rosybrown
      case royalblue
      case saddlebrown
      case salmon
      case sandybrown
      case seagreen
      case seashell
      case sienna
      case silver
      case skyblue
      case slateblue
      case slategray
      case slategrey
      case snow
      case springgreen
      case steelblue
      case tan
      case teal
      case thistle
      case tomato
      case turquoise
      case violet
      case wheat
      case white
      case whitesmoke
      case yellow
      case yellowgreen
    }
  }
}

extension DOM.Color.Keyword {
  
  // each color keyword maps to an rgbi
  var rgbi: (UInt8, UInt8, UInt8) {
    switch self {
    case .aliceblue: return (240, 248, 255)
    case .antiquewhite: return (250, 235, 215)
    case .aqua: return (0, 255, 255)
    case .aquamarine: return (127, 255, 212)
    case .azure: return (240, 255, 255)
    case .beige: return (245, 245, 220)
    case .bisque: return (255, 228, 196)
    case .black: return (0, 0, 0)
    case .blanchedalmond: return (255, 235, 205)
    case .blue: return (0, 0, 255)
    case .blueviolet: return (138, 43, 226)
    case .brown: return (165, 42, 42)
    case .burlywood: return (222, 184, 135)
    case .cadetblue: return (95, 158, 160)
    case .chartreuse: return (127, 255, 0)
    case .chocolate: return (210, 105, 30)
    case .coral: return (255, 127, 80)
    case .cornflowerblue: return (100, 149, 237)
    case .cornsilk: return (255, 248, 220)
    case .crimson: return (220, 20, 60)
    case .cyan: return (0, 255, 255)
    case .darkblue: return (0, 0, 139)
    case .darkcyan: return (0, 139, 139)
    case .darkgoldenrod: return (184, 134, 11)
    case .darkgray: return (169, 169, 169)
    case .darkgreen: return (0, 100, 0)
    case .darkgrey: return (169, 169, 169)
    case .darkkhaki: return (189, 183, 107)
    case .darkmagenta: return (139, 0, 139)
    case .darkolivegreen: return (85, 107, 47)
    case .darkorange: return (255, 140, 0)
    case .darkorchid: return (153, 50, 204)
    case .darkred: return (139, 0, 0)
    case .darksalmon: return (233, 150, 122)
    case .darkseagreen: return (143, 188, 143)
    case .darkslateblue: return (72, 61, 139)
    case .darkslategray: return (47, 79, 79)
    case .darkslategrey: return (47, 79, 79)
    case .darkturquoise: return (0, 206, 209)
    case .darkviolet: return (148, 0, 211)
    case .deeppink: return (255, 20, 147)
    case .deepskyblue: return (0, 191, 255)
    case .dimgray: return (105, 105, 105)
    case .dimgrey: return (105, 105, 105)
    case .dodgerblue: return (30, 144, 255)
    case .firebrick: return (178, 34, 34)
    case .floralwhite: return (255, 250, 240)
    case .forestgreen: return (34, 139, 34)
    case .fuchsia: return (255, 0, 255)
    case .gainsboro: return (220, 220, 220)
    case .ghostwhite: return (248, 248, 255)
    case .gold: return (255, 215, 0)
    case .goldenrod: return (218, 165, 32)
    case .gray: return (128, 128, 128)
    case .grey: return (128, 128, 128)
    case .green: return (0, 128, 0)
    case .greenyellow: return (173, 255, 47)
    case .honeydew: return (240, 255, 240)
    case .hotpink: return (255, 105, 180)
    case .indianred: return (205, 92, 92)
    case .indigo: return (75, 0, 130)
    case .ivory: return (255, 255, 240)
    case .khaki: return (240, 230, 140)
    case .lavender: return (230, 230, 250)
    case .lavenderblush: return (255, 240, 245)
    case .lawngreen: return (124, 252, 0)
    case .lemonchiffon: return (255, 250, 205)
    case .lightblue: return (173, 216, 230)
    case .lightcoral: return (240, 128, 128)
    case .lightcyan: return (224, 255, 255)
    case .lightgoldenrodyellow: return (250, 250, 210)
    case .lightgray: return (211, 211, 211)
    case .lightgreen: return (144, 238, 144)
    case .lightgrey: return (211, 211, 211)
    case .lightpink: return (255, 182, 193)
    case .lightsalmon: return (255, 160, 122)
    case .lightseagreen: return (32, 178, 170)
    case .lightskyblue: return (135, 206, 250)
    case .lightslategray: return (119, 136, 153)
    case .lightslategrey: return (119, 136, 153)
    case .lightsteelblue: return (176, 196, 222)
    case .lightyellow: return (255, 255, 224)
    case .lime: return (0, 255, 0)
    case .limegreen: return (50, 205, 50)
    case .linen: return (250, 240, 230)
    case .magenta: return (255, 0, 255)
    case .maroon: return (128, 0, 0)
    case .mediumaquamarine: return (102, 205, 170)
    case .mediumblue: return (0, 0, 205)
    case .mediumorchid: return (186, 85, 211)
    case .mediumpurple: return (147, 112, 219)
    case .mediumseagreen: return (60, 179, 113)
    case .mediumslateblue: return (123, 104, 238)
    case .mediumspringgreen: return (0, 250, 154)
    case .mediumturquoise: return (72, 209, 204)
    case .mediumvioletred: return (199, 21, 133)
    case .midnightblue: return (25, 25, 112)
    case .mintcream: return (245, 255, 250)
    case .mistyrose: return (255, 228, 225)
    case .moccasin: return (255, 228, 181)
    case .navajowhite: return (255, 222, 173)
    case .navy: return (0, 0, 128)
    case .oldlace: return (253, 245, 230)
    case .olive: return (128, 128, 0)
    case .olivedrab: return (107, 142, 35)
    case .orange: return (255, 165, 0)
    case .orangered: return (255, 69, 0)
    case .orchid: return (218, 112, 214)
    case .palegoldenrod: return (238, 232, 170)
    case .palegreen: return (152, 251, 152)
    case .paleturquoise: return (175, 238, 238)
    case .palevioletred: return (219, 112, 147)
    case .papayawhip: return (255, 239, 213)
    case .peachpuff: return (255, 218, 185)
    case .peru: return (205, 133, 63)
    case .pink: return (255, 192, 203)
    case .plum: return (221, 160, 221)
    case .powderblue: return (176, 224, 230)
    case .purple: return (128, 0, 128)
    case .red: return (255, 0, 0)
    case .rosybrown: return (188, 143, 143)
    case .royalblue: return (65, 105, 225)
    case .saddlebrown: return (139, 69, 19)
    case .salmon: return (250, 128, 114)
    case .sandybrown: return (244, 164, 96)
    case .seagreen: return (46, 139, 87)
    case .seashell: return (255, 245, 238)
    case .sienna: return (160, 82, 45)
    case .silver: return (192, 192, 192)
    case .skyblue: return (135, 206, 235)
    case .slateblue: return (106, 90, 205)
    case .slategray: return (112, 128, 144)
    case .slategrey: return (112, 128, 144)
    case .snow: return (255, 250, 250)
    case .springgreen: return (0, 255, 127)
    case .steelblue: return (70, 130, 180)
    case .tan: return (210, 180, 140)
    case .teal: return (0, 128, 128)
    case .thistle: return (216, 191, 216)
    case .tomato: return (255, 99, 71)
    case .turquoise: return (64, 224, 208)
    case .violet: return (238, 130, 238)
    case .wheat: return (245, 222, 179)
    case .white: return (255, 255, 255)
    case .whitesmoke: return (245, 245, 245)
    case .yellow: return (255, 255, 0)
    case .yellowgreen: return (154, 205, 50)
    }
  }
}
