//
//  GalleryView.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/2/25.
//  Copyright 2019 Simon Whitty
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

import SwiftDraw
import SwiftUI

struct GalleryView: View {

    var imageNames: [String] = [
        "avocado.svg",
        "angry.svg",
        "dish.svg",
        "mouth-open.svg",
        "sleepy.svg",
        "smile.svg",
        "snake.svg",
        "spider.svg",
        "star-struck.svg",
        "worried.svg",
        "yawning.svg",
        "thats-no-moon.svg",
        "alert.svg"
    ]

    var body: some View {
        if #available(iOS 15.0, *) {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(imageNames, id: \.self) { name in
                        SVGView(name, bundle: .samples)
                            .aspectRatio(contentMode: .fit)
                            .padding([.leading, .trailing], 10)
                           // .frame(maxWidth: 320)
                    }
                }
                .background(Color.white)
            }

        }
    }
}
