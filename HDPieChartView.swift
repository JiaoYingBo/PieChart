
import Foundation
import UIKit
import DGCharts

open class HDPieChartView: PieChartView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        renderer = HDPieChartRenderer.init(withChart: self, animator: self.chartAnimator, viewPortHandler: self.viewPortHandler)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("error")
    }
}
