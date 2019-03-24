//
//  SegmentedGaugeBarLayer.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 3/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit


class SegmentedGaugeBarLayer: CALayer {

    var numberOfSegments = 1 {
        didSet {
            setNeedsDisplay()
        }
    }

    var startColor = UIColor.white.cgColor {
        didSet {
            setNeedsDisplay()
        }
    }

    var endColor = UIColor.black.cgColor {
        didSet {
            setNeedsDisplay()
        }
    }

    var gaugeBorderWidth: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    var gaugeBorderColor = UIColor.black.cgColor {
        didSet {
            setNeedsDisplay()
        }
    }

    @NSManaged var progress: CGFloat

    override class func needsDisplay(forKey key: String) -> Bool {
        return key == #keyPath(SegmentedGaugeBarLayer.progress)
            || super.needsDisplay(forKey: key)
    }

    override func action(forKey event: String) -> CAAction? {
        if event == #keyPath(progress) {
            let animation = CABasicAnimation(keyPath: event)
            animation.fromValue = presentation()?.progress
            return animation
        } else {
            return super.action(forKey: event)
        }
    }

    override func display() {
        contents = contentImage()
    }

    private func contentImage() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let uiImage = renderer.image { context in
            drawGauge(in: context.cgContext)
        }
        return uiImage.cgImage
    }

    private func drawGauge(in context: CGContext) {
        for countFromRight in segmentCounts {
            drawSegment(atCountFromRight: countFromRight, in: context)
        }
    }

    private var segmentCounts: ClosedRange<Int> {
        return 1...numberOfSegments
    }

    private func drawSegment(atCountFromRight countFromRight: Int, in context: CGContext) {
        let isRightmostSegment = countFromRight == segmentCounts.lowerBound
        let isLeftmostSegment = countFromRight == segmentCounts.upperBound
        let fillFraction = (presentationProgress - CGFloat(numberOfSegments - countFromRight)).clamped(to: 0...1)
        let (segmentSize, roundedCorners): (CGSize, UIRectCorner) = {
            if isLeftmostSegment {
                return (leftmostSegmentSize, .allCorners)
            } else {
                return (normalSegmentSize, [.topRight, .bottomRight])
            }
        }()

        let segmentOrigin = CGPoint(
            x: bounds.width - gaugeBorderWidth / 2 - CGFloat(countFromRight) * segmentSize.width,
            y: bounds.minY + gaugeBorderWidth / 2
        )
        let segmentRect = CGRect(origin: segmentOrigin, size: segmentSize)

        let borderPath = UIBezierPath(roundedRect: segmentRect, byRoundingCorners: roundedCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))

        let borderColor = fillFraction > 0
            ? gaugeBorderColor
            : UIColor(cgColor: gaugeBorderColor).withAlphaComponent(0.5).cgColor

        coverSegment(tracedBy: borderPath, in: context)
        defer {
            drawBorder(borderPath, color: borderColor, in: context)
        }

        guard fillFraction > 0 else {
            return
        }

        var segmentFillRect = CGRect(origin: segmentOrigin, size: leftmostSegmentSize).insetBy(dx: fillInset, dy: fillInset)
        segmentFillRect.size.width *= fillFraction
        if !isLeftmostSegment {
            segmentFillRect.size.width += segmentOverlap
        }

        let segmentFillPath = UIBezierPath(roundedRect: segmentFillRect, byRoundingCorners: roundedCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        drawGradient(over: segmentFillPath, in: context)

        if !isRightmostSegment {
            drawNegativeSpacePath(negativeSpacePath(for: segmentRect), in: context)
        }
    }

    private var fillInset: CGFloat {
        return 1.5 * gaugeBorderWidth
    }

    private var segmentOverlap: CGFloat {
        return cornerRadius
    }

    private var presentationProgress: CGFloat {
        return presentation()?.progress ?? self.progress
    }

    private var leftmostSegmentSize: CGSize {
        return CGSize(
            width: (bounds.width - gaugeBorderWidth) / CGFloat(numberOfSegments),
            height: bounds.height - gaugeBorderWidth
        )
    }

    private var normalSegmentSize: CGSize {
        return CGSize(
            width: leftmostSegmentSize.width + segmentOverlap,
            height: leftmostSegmentSize.height
        )
    }

    private func negativeSpacePath(for segmentRect: CGRect) -> UIBezierPath {
        var negativeSpaceRect = segmentRect.insetBy(dx: gaugeBorderWidth, dy: gaugeBorderWidth)
        negativeSpaceRect.size.width += gaugeBorderWidth * 2
        return UIBezierPath(roundedRect: negativeSpaceRect, cornerRadius: cornerRadius)
    }

    private func coverSegment(tracedBy path: UIBezierPath, in context: CGContext) {
        // Cover the segment area with the background color to hide overlapping borders
        context.addPath(path.cgPath)
        context.setFillColor(backgroundColor ?? UIColor.white.cgColor)
        context.fillPath()
    }

    private func drawGradient(over path: UIBezierPath, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        context.addPath(path.cgPath)
        context.clip()

        let pathBounds = path.bounds
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [gradientColor(atX: pathBounds.minX),
                     gradientColor(atX: pathBounds.maxX)] as CFArray,
            locations: [0, 1]
        )!

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: pathBounds.minX, y: pathBounds.midY),
            end: CGPoint(x: pathBounds.maxX, y: pathBounds.midY),
            options: []
        )
    }

    private func drawNegativeSpacePath(_ path: UIBezierPath, in context: CGContext) {
        context.setStrokeColor(backgroundColor ?? UIColor.white.cgColor)
        context.setLineWidth(gaugeBorderWidth)
        context.addPath(path.cgPath)
        context.strokePath()
    }

    private func drawBorder(_ path: UIBezierPath, color: CGColor, in context: CGContext) {
        context.addPath(path.cgPath)
        context.setLineWidth(gaugeBorderWidth)
        context.setStrokeColor(color)
        context.strokePath()
    }

    private func gradientColor(atX x: CGFloat) -> CGColor {
        return UIColor.interpolatingBetween(
            UIColor(cgColor: startColor),
            UIColor(cgColor: endColor),
            biasTowardSecondColor: fractionThrough(x, in: bounds.minX...bounds.maxX)
        ).cgColor
    }
}
