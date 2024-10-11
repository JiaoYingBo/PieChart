
/**
 参考：《iOS 解决Charts框架PieChartView标签重叠问题》 https://www.jianshu.com/p/88a77167028c
 */
import UIKit
import Foundation
import CoreGraphics
import DGCharts

open class HDPieChartRenderer: PieChartRenderer{
    init(withChart chart:PieChartView, animator:Animator, viewPortHandler:ViewPortHandler){
        super.init(chart: chart, animator: animator, viewPortHandler: viewPortHandler)
    }
    private func minData(_ recordY:Array<Array<CGFloat>>, pt1y:CGFloat)->Array<CGFloat>{
        var bigD:Array<CGFloat> = Array<CGFloat>()
        var nearestlist:Array<CGFloat> = Array<CGFloat>()
        var nearestlistCopy:Array<CGFloat> = Array<CGFloat>()
        for k in 0..<recordY[0].count {
            if recordY[0][k] != 0 {
                bigD.append(abs(recordY[0][k] - pt1y))
                nearestlist.append(recordY[0][k])
                nearestlistCopy.append(recordY[1][k])
            }
        }
        //距离最近的点，数值
        var rF:Array = [CGFloat](repeating: 0, count: 2)
        if bigD.count == 0 {
            return rF
        }
        var minD = bigD[0]
        rF[0] = nearestlist[0]
        rF[1] = nearestlistCopy[0]
        for g in 0..<bigD.count {
            if bigD[g] < minD {
                minD = bigD[g]
                rF[0] = nearestlist[g]
                rF[1] = nearestlistCopy[g]
            }
        }
        return rF
    }
    open override func drawValues(context: CGContext)
    {
        guard
            let chart = chart,
            let data = chart.data
            else { return }
        let center = chart.centerCircleBox
        // get whole the radius
        let radius = chart.radius
        let rotationAngle = chart.rotationAngle
        let drawAngles = chart.drawAngles
        let absoluteAngles = chart.absoluteAngles
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        var labelRadiusOffset = radius / 10.0 * 3.0
        if chart.drawHoleEnabled
        {
            labelRadiusOffset = (radius - (radius * chart.holeRadiusPercent)) / 2.0
        }
        let labelRadius = radius - labelRadiusOffset
        let dataSets = data.dataSets
        let yValueSum = (data as! PieChartData).yValueSum
        let drawEntryLabels = chart.isDrawEntryLabelsEnabled
        let usePercentValuesEnabled = chart.usePercentValuesEnabled
        var angle: CGFloat = 0.0
        var xIndex = 0
        context.saveGState()
        defer { context.restoreGState() }
        for i in 0 ..< dataSets.count
        {
            guard let dataSet = dataSets[i] as? PieChartDataSet else { continue }
            let drawValues = dataSet.isDrawValuesEnabled
            if !drawValues && !drawEntryLabels && !dataSet.isDrawIconsEnabled
            {
                continue
            }
            let iconsOffset = dataSet.iconsOffset
            let xValuePosition = dataSet.xValuePosition
            let yValuePosition = dataSet.yValuePosition
            let valueFont = dataSet.valueFont
            let entryLabelFont = dataSet.entryLabelFont ?? chart.entryLabelFont
            let lineHeight = valueFont.lineHeight
            let textHeight = entryLabelFont?.lineHeight
            let formatter = dataSet.valueFormatter
            var leftRecordY = [[CGFloat]](repeating: [CGFloat](repeating: 0, count: dataSet.entryCount), count: 2)
            var rightRecordY = [[CGFloat]](repeating: [CGFloat](repeating: 0, count: dataSet.entryCount), count: 2)
            for j in 0 ..< dataSet.entryCount
            {
                guard let e = dataSet.entryForIndex(j) else { continue }
                let pe = e as? PieChartDataEntry
                if xIndex == 0
                {
                    angle = 0.0
                }
                else
                {
                    angle = absoluteAngles[xIndex - 1] * CGFloat(phaseX)
                }
                let sliceAngle = drawAngles[xIndex]
                let sliceSpace = getSliceSpace(dataSet: dataSet)
                let sliceSpaceMiddleAngle = sliceSpace / (labelRadius * .pi / 180)
                // offset needed to center the drawn text in the slice
                let angleOffset = (sliceAngle - sliceSpaceMiddleAngle / 2.0) / 2.0
                angle = angle + angleOffset
                let transformedAngle = rotationAngle + angle * CGFloat(phaseY)
                let value = usePercentValuesEnabled ? e.y / yValueSum * 100.0 : e.y
                let valueText = formatter.stringForValue(
                    value,
                    entry: e,
                    dataSetIndex: i,
                    viewPortHandler: viewPortHandler)
                let sliceXBase = cos(transformedAngle * .pi / 180)
                let sliceYBase = sin(transformedAngle * .pi / 180)
                let drawXOutside = drawEntryLabels && xValuePosition == .outsideSlice
                let drawYOutside = drawValues && yValuePosition == .outsideSlice
                let drawXInside = drawEntryLabels && xValuePosition == .insideSlice
                let drawYInside = drawValues && yValuePosition == .insideSlice
                let valueTextColor = dataSet.valueTextColorAt(j)
                let entryLabelColor = dataSet.entryLabelColor ?? chart.entryLabelColor
                if drawXOutside || drawYOutside
                {
                    let valueLineLength1 = dataSet.valueLinePart1Length
                    let valueLineLength2 = dataSet.valueLinePart2Length
                    let valueLinePart1OffsetPercentage = dataSet.valueLinePart1OffsetPercentage
                    var pt2: CGPoint
                    var labelPoint: CGPoint
                    var align: NSTextAlignment
                    var line1Radius: CGFloat
                    if chart.drawHoleEnabled
                    {
                        line1Radius = (radius - (radius * chart.holeRadiusPercent)) * valueLinePart1OffsetPercentage + (radius * chart.holeRadiusPercent)
                    }
                    else
                    {
                        line1Radius = radius * valueLinePart1OffsetPercentage
                    }
                    let polyline2Length = dataSet.valueLineVariableLength
                        ? labelRadius * valueLineLength2 * abs(sin(transformedAngle * .pi / 180))
                        : labelRadius * valueLineLength2
                    let pt0 = CGPoint(
                        x: line1Radius * sliceXBase + center.x,
                        y: line1Radius * sliceYBase + center.y)
                    var pt1 = CGPoint(
                        x: labelRadius * (1 + valueLineLength1) * sliceXBase + center.x,
                        y: labelRadius * (1 + valueLineLength1) * sliceYBase + center.y)
                    if transformedAngle.truncatingRemainder(dividingBy: 360.0) >= 90.0 && transformedAngle.truncatingRemainder(dividingBy: 360.0) <= 270.0
                    {
                        let nearestPoint = minData(leftRecordY, pt1y: pt1.y)
                        leftRecordY[0][j] = pt1.y
                        //判断是否需要挪位置
                        if (nearestPoint[0] != 0) && (abs(nearestPoint[0] - pt1.y) < (textHeight! + lineHeight)) {
                            pt1 = CGPoint(x: pt1.x, y: nearestPoint[1] - textHeight!)
                        }
                        pt2 = CGPoint(x: pt1.x - polyline2Length, y: pt1.y)
                        align = .right
                        labelPoint = CGPoint(x: pt2.x - 5, y: pt2.y - textHeight!)
                        leftRecordY[1][j] = pt1.y
                    }
                    else
                    {
                        let nearestPoint = minData(rightRecordY, pt1y: pt1.y)
                        rightRecordY[0][j] = pt1.y
                        //判断是否需要挪位置
                        if (nearestPoint[0] != 0) && (abs(nearestPoint[0] - pt1.y) < (textHeight! + lineHeight)){
                            pt1 = CGPoint(x: pt1.x, y: nearestPoint[1] + textHeight!)
                        }
                        pt2 = CGPoint(x: pt1.x + polyline2Length, y: pt1.y)
                        align = .left
                        labelPoint = CGPoint(x: pt2.x + 5, y: pt2.y - textHeight!)
                        rightRecordY[1][j] = pt1.y
                    }
                    DrawLine: do
                    {
                        if dataSet.useValueColorForLine
                        {
                            context.setStrokeColor(dataSet.color(atIndex: j).cgColor)
                        }
                        else if let valueLineColor = dataSet.valueLineColor
                        {
                            context.setStrokeColor(valueLineColor.cgColor)
                        }
                        else
                        {
                            return
                        }
                        context.setLineWidth(dataSet.valueLineWidth)
                        context.move(to: CGPoint(x: pt0.x, y: pt0.y))
                        context.addLine(to: CGPoint(x: pt1.x, y: pt1.y))
                        context.addLine(to: CGPoint(x: pt2.x, y: pt2.y))
                        context.drawPath(using: CGPathDrawingMode.stroke)
                    }
                    if drawXOutside && drawYOutside
                    {
                        context.drawText(valueText,
                                         at: labelPoint,
                                         align: align,
                                         attributes: [NSAttributedString.Key.font: valueFont, NSAttributedString.Key.foregroundColor: valueTextColor]
                                        )
                        if j < data.entryCount && pe?.label != nil
                        {
                            context.drawText(pe!.label!,
                                             at: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight),
                                             align: align,
                                             attributes: [
                                                            NSAttributedString.Key.font: entryLabelFont ?? valueFont,
                                                            NSAttributedString.Key.foregroundColor: entryLabelColor ?? valueTextColor]
                                            )
                        }
                    }
                    else if drawXOutside
                    {
                        if j < data.entryCount && pe?.label != nil
                        {
                            context.drawText(pe!.label!,
                                             at: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight / 2.0),
                                             align: align,
                                             attributes: [
                                                            NSAttributedString.Key.font: entryLabelFont ?? valueFont,
                                                            NSAttributedString.Key.foregroundColor: entryLabelColor ?? valueTextColor]
                                            )
                        }
                    }
                    else if drawYOutside
                    {
                        context.drawText(valueText,
                                         at: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight / 2.0),
                                         align: align,
                                         attributes: [NSAttributedString.Key.font: valueFont, NSAttributedString.Key.foregroundColor: valueTextColor]
                                        )
                    }
                }
                if drawXInside || drawYInside
                {
                    // calculate the text position
                    let x = labelRadius * sliceXBase + center.x
                    let y = labelRadius * sliceYBase + center.y - lineHeight
                    if drawXInside && drawYInside
                    {
                        context.drawText(valueText,
                                         at: CGPoint(x: x, y: y),
                                         align: .center,
                                         attributes: [NSAttributedString.Key.font: valueFont, NSAttributedString.Key.foregroundColor: valueTextColor]
                                        )
                        if j < data.entryCount && pe?.label != nil
                        {
                            context.drawText(pe!.label!,
                                             at: CGPoint(x: x, y: y + lineHeight),
                                             align: .center,
                                             attributes: [
                                                            NSAttributedString.Key.font: entryLabelFont ?? valueFont,
                                                            NSAttributedString.Key.foregroundColor: entryLabelColor ?? valueTextColor]
                                            )
                        }
                    }
                    else if drawXInside
                    {
                        if j < data.entryCount && pe?.label != nil
                        {
                            context.drawText(pe!.label!,
                                             at: CGPoint(x: x, y: y + lineHeight / 2.0),
                                             align: .center,
                                             attributes: [
                                                            NSAttributedString.Key.font: entryLabelFont ?? valueFont,
                                                            NSAttributedString.Key.foregroundColor: entryLabelColor ?? valueTextColor]
                                            )
                        }
                    }
                    else if drawYInside
                    {
                        context.drawText(valueText,
                                         at: CGPoint(x: x, y: y + lineHeight / 2.0),
                                         align: .center,
                                         attributes: [NSAttributedString.Key.font: valueFont, NSAttributedString.Key.foregroundColor: valueTextColor]
                                        )
                    }
                }
                
                if let icon = e.icon, dataSet.isDrawIconsEnabled
                {
                    // calculate the icon's position
                    let x = (labelRadius + iconsOffset.y) * sliceXBase + center.x
                    var y = (labelRadius + iconsOffset.y) * sliceXBase + center.y
                    y += iconsOffset.x
                    context.drawImage(icon, atCenter: CGPoint(x: x, y: y), size: icon.size)
                }
                xIndex += 1
            }
        }
    }
}
