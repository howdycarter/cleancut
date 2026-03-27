//
//  AnimatedBackground.swift
//

import SwiftUI

struct AnimatedBackground: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let colors = [DS.primary, DS.accent]
                for i in 0..<6 {
                    let phase = t / 6 + Double(i) * 0.35
                    let x = cos(phase) * (size.width * 0.25) + size.width * [0.2,0.8,0.5,0.7,0.3,0.6][i % 6]
                    let y = sin(phase) * (size.height * 0.25) + size.height * [0.2,0.3,0.7,0.5,0.8,0.6][i % 6]
                    let rect = CGRect(x: x-120, y: y-120, width: 240, height: 240)
                    ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [colors[i%2].opacity(0.35), .clear]), center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 10, endRadius: 160))
                }
            }
        }
        .ignoresSafeArea()
    }
}

