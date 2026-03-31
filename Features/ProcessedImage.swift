//
//  ProcessedImage.swift
//  CleanCut
//
import UIKit

struct ProcessedImage: Identifiable {
    let id = UUID()
    let original: UIImage
    let processed: UIImage
    var background: BackgroundType = .transparent
    var customColor: UIColor = .white
}
