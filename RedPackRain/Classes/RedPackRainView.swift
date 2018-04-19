//
//  RedPackRainView.swift
//  RedPackRain
//
//  Created by Orange on 2018/4/11.
//  Copyright © 2018年 Orange. All rights reserved.
//

import UIKit

public class RedPackRainView: UIView {
    public typealias ClickHandle = (RedPackRainView, UIView) -> Void
    public typealias CompleteHandle = (RedPackRainView) -> Void
    /// 定时器
    public var timer:Timer = Timer.init()
    /// 红包总数
    public private(set) var redPackAllCount = 0
    /// 点中的红包数
    public private(set) var redPackClickedCount = 0
    /// 发红包间隔时间
    public var redPackIntervalTime = 0.0
    /// 红包下落速度,到底部时间
    public var redPackDropDownTime = 0.0
    /// 红包雨持续时间
    public var totalTime = 0.0

    public let redPackCompomentTag = -999

    
    private var redPackSize: CGSize?
    private var redPackImages: [UIImage]?
    private var redPackAnimationDuration: Double?
    private var clickHandle: ClickHandle?
    private var completeHandle: CompleteHandle?
    private var timeCounter = 0
    // MARK: 初始化设置
    public override init(frame: CGRect) {
        super.init(frame: frame)
                let tap = UITapGestureRecognizer()
                tap.addTarget(self, action: #selector(self.clicked))
                self.addGestureRecognizer(tap)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    /// 红包设置
    ///
    /// - Parameters:
    ///   - images: 红包图片集 ,会循环轮播
    ///   - size: 红包的图片大小,不设和图片等大
    ///   - animationDuration: 轮播间隔,默认 1秒
    ///   - intervalTime: 红包间隔, 默认 0.5秒 一封
    ///   - dropDownTime: 红包落下时间, 默认 5秒落到底部
    ///   - totalTime: 总动画时间
    ///   - clickedHandle: 点击红包回调
    public func setRedPack(
        images: [UIImage]?,
        size: CGSize? = nil,
        animationDuration: Double? = 1,
        intervalTime: Double = 0.5,
        dropDownTime: Double = 5,
        totalTime: Double = 30,
        clickedHandle: ClickHandle? = nil
        ) {
        self.redPackSize = size
        self.redPackImages = images
        self.redPackAnimationDuration = animationDuration
        self.redPackIntervalTime = intervalTime
        self.redPackDropDownTime = dropDownTime
        self.totalTime = totalTime
        self.clickHandle = clickedHandle
    }
    
    
    /// 红包雨结束回调
    ///
    /// - Parameter completeHandle: 回调handle
    public func setCompleteHandle(completeHandle: @escaping CompleteHandle) {
        self.completeHandle = completeHandle
    }
    
    // MARK: 动画
    public func beginToRain() {
        //防止timer重复添加
        self.timer.invalidate()
        self.timer =  Timer.scheduledTimer(timeInterval: redPackIntervalTime, target: self, selector: #selector(showRain), userInfo: "", repeats: true)
    }
    
    public func endRain() {
        self.timer.invalidate()
        //停止所有layer的动画
        for subview in subviews {
            subview.layer.removeAllAnimations()
            subview.removeFromSuperview()
        }
        completeHandle?(self)
    }
    
    // MARK: 私有方法
    @objc private func showRain() {
        let rest = totalTime - Double(timeCounter) * redPackIntervalTime
        guard  rest > 0 else {
            endRain()
            return
        }
//        print("红包 +1,倒计时 \(rest)s")
        timeCounter += 1
        show()
    }
    
    private func show() {
        let size = redPackSize ?? CGSize.init(width: 50, height: 50)
        //创建画布
        let imageView = UIImageView.init()
        imageView.tag = redPackCompomentTag
        imageView.image = redPackImages?.first
        imageView.animationImages = redPackImages
        imageView.isUserInteractionEnabled = true
        if let duration = redPackAnimationDuration {
            imageView.animationDuration = duration
        }
        imageView.startAnimating()
        imageView.frame = CGRect.init(origin: CGPoint.zero, size: size)
        imageView.frame.origin.y =  -size.height
        self.insertSubview(imageView, at: 0)
        redPackAllCount += 1
        //画布动画
        addAnimation(imageView: imageView)
    }
    
    //给画布添加动画
    func addAnimation(imageView: UIImageView) {
        let moveLayer = imageView.layer
        //此处keyPath为CALayer的属性
        let  moveAnimation:CAKeyframeAnimation = CAKeyframeAnimation(keyPath:"position")
        //动画路线，一个数组里有多个轨迹点
        moveAnimation.values = [NSValue(cgPoint: CGPoint(x: CGFloat(Float(arc4random_uniform(UInt32(self.frame.width)))), y: -imageView.frame.height)),NSValue(cgPoint: CGPoint(x:CGFloat(Float(arc4random_uniform(UInt32(self.frame.width)))), y: self.frame.height))]
        //动画间隔
        moveAnimation.duration = redPackDropDownTime
        //重复次数
        moveAnimation.repeatCount = 1
        //动画的速度
        moveAnimation.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionLinear)
        CATransaction.setCompletionBlock {
            imageView.removeFromSuperview()
        }
        moveLayer.add(moveAnimation, forKey: "move")
    }
    
    
    @objc func clicked(tapgesture: UITapGestureRecognizer) {
        let touchPoint = tapgesture.location(in: self)
        let views = self.subviews
        for viewTuple in views.enumerated() {
            if viewTuple.element.layer.presentation()?
                .hitTest(touchPoint) != nil &&
                viewTuple.element.tag == redPackCompomentTag {
                redPackClickedCount += 1
                clickHandle?(self, viewTuple.element)
            }
        }
    }
}
