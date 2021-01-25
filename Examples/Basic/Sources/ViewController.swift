//
//  ViewController.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 10/2/19.
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
import UIKit

class ViewController: UIViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = "SVG"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Mode", style: .plain, target: self, action: #selector(didTap))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func didTap() {
        guard let contentMode = imageViewIfLoaded?.contentMode else { return }
        switch contentMode {
        case .center:
            imageViewIfLoaded?.contentMode = .scaleAspectFit
        case .scaleAspectFit:
            imageViewIfLoaded?.contentMode = .scaleAspectFill
        case .scaleAspectFill:
            imageViewIfLoaded?.contentMode = .center
        default:
            imageViewIfLoaded?.contentMode = .center
        }
    }

    var imageViewIfLoaded: UIImageView? {
        return viewIfLoaded as? UIImageView
    }

    override func loadView() {
        let imageView = UIImageView(frame: UIScreen.main.bounds)
        imageView.image = Image(named: "rings.svg")?.pdfImage()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        self.view = imageView
    }
}

private extension Image {

  // UIImage backed with PDF preserves vector data.

  func pdfImage() -> UIImage? {
    guard
      let data = pdfData(),
      let provider = CGDataProvider(data: data as CFData),
      let pdf = CGPDFDocument(provider),
      let page = pdf.page(at: 1) else {
        return nil
    }

    return UIImage
      .perform(NSSelectorFromString("_imageWithCGPDFPage:"), with: page)?
      .takeUnretainedValue() as? UIImage
  }
}
