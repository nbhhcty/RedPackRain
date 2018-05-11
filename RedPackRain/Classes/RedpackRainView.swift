//
//  RedPackRainView.swift
//  RedPackRain
//
//  Created by Orange on 2018/4/11.
//  Copyright © 2018年 Orange. All rights reserved.
//

import UIKit

@objc protocol RedpackRainDelegate {
    /// 红包出现
    @objc optional func redpackDidAppear(rainView: RedpackRainView, redpack: UIView, index: Int) -> Void
    /// 红包被点中
    @objc optional func redpackDidClicked(rainView: RedpackRainView, redpack: UIView) -> Void

    /// 炸弹出现
    @objc optional func bombDidAppear(rainView: RedpackRainView, bomb: UIView, index: Int) -> Void
    ///  炸弹被点中
    @objc optional func bombDidClicked(rainView: RedpackRainView, bomb: UIView) -> Void
}


public class RedpackRainView: UIView {
    weak var delegate: RedpackRainDelegate?

    /// 红包点击回调
    public typealias ClickHandle = (RedpackRainView, UIView) -> Void
    /// 炸弹点击回调
    public typealias BombClickHandle = (RedpackRainView, UIView) -> Void

    /// 红包出现回调
    public typealias RedPackAppearHandle = (UIImageView, Int) -> Void
    /// 炸弹出现回调
    public typealias BombAppearHandle = (UIImageView, Int) -> Void
    /// 红包雨结束回调(包括正常与非正常结束)
    public typealias CompleteHandle = (RedpackRainView) -> Void

    // MARK: - 红包
    /// 红包view列表
    public var redPackList: [UIImageView] = []
    public var redPackImages: [UIImage] = []
    /// 定时器
    public var timer: Timer = Timer.init()
    /// 红包总数
    public private(set) var redPackAllCount = 0
    /// 点中的红包数
    public private(set) var redPackClickedCount = 0
    /// 最小红包间隔周期,0.01 秒
    public let minRedPackIntervalTime = 0.01
    /// 发红包间隔时间
    public var redPackIntervalTime = 0.0 {
        didSet {
            if redPackIntervalTime < 0.01 {
                redPackIntervalTime = 0.01
            }
        }
    }

    private var runShowFuncCount: Double {
        get {
            return redPackIntervalTime / minRedPackIntervalTime
        }
    }

    /// 已执行时间
    public private(set) var runTimeTotal: Double = 0
    /// 剩余时间
    public var restTime: Double { return totalTime - runTimeTotal }

    /// 红包下落速度,到底部时间
    public var redPackDropDownTime = 0.0
    /// 红包雨持续总时间
    public var totalTime = 0.0

    /// 是否开启点击穿透, 点击效果可以穿透上层的遮挡物
    public var clickPenetrateEnable = false
    /// 三种标记, -1001: 不可穿透的遮罩, -999: 红包, -1000: 炸弹
    public let notPenetrateTag = -1001
    public let redPackCompomentTag = -999
    public let bombCompomentTag = -1000



    private var redPackSize: CGSize?
    private var redPackAnimationDuration: Double?
    private var runShowCount = 0 // 每 x 步执行计数器,用户设置
    private private(set) var timeCounter = 0  // 最小步长计数器, 0.01 秒计数一次

    private var clickHandle: ClickHandle?
    private var completeHandle: CompleteHandle?
    private var redPackAppearHandle: RedPackAppearHandle?

    // MARK: - 炸弹
    /// 炸弹密度,每10个红包一个炸弹
    public var bombList: [UIImageView] = []
    public var bombImages: [UIImage] = []
    /// 炸弹频率,每x个红包出现一个炸弹,默认 0 则没有炸弹
    public var bombDensity = 0
    /// 炸弹总数计数器
    public private(set) var bombAllCount = 0
    /// 点中的炸弹数
    public private(set) var bombClickedCount = 0

    private var bombSize: CGSize? // 图片大小
    private var bombAppearHandle: BombAppearHandle?
    private var bombClickHandle: BombClickHandle? = nil
    
    // MARK: 初始化设置
    public override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer()
        tap.addTarget(self, action: #selector(self.clicked))
        addGestureRecognizer(tap)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: 启动函数
    public func startGame(configBlock: ((RedpackRainView) -> Void)? = nil) {
        //防止timer重复添加
        resetValue()
        configBlock?(self)
        self.timer =  Timer.scheduledTimer(timeInterval: minRedPackIntervalTime, target: self, selector: #selector(showRain), userInfo: "", repeats: true)
    }

    /// 结束游戏
    public func endGame() {
        self.timer.invalidate()
        // 清除界面红包和炸弹
        clearAllBomb()
        clearAllRedPack()
        completeHandle?(self)
    }

    /// 暂停红包雨
    public func stopRain() {
        self.timer.invalidate()
        stopRedPack()
        stopBomb()
    }


    /// 继续下落红包雨
    public func continueRain() {
        self.timer.invalidate()
        self.timer =  Timer.scheduledTimer(timeInterval: minRedPackIntervalTime, target: self, selector: #selector(showRain), userInfo: "", repeats: true)
        resumeRedPack()
        resumeBomb()
    }

    // MARK: - 重置方法
    /// 重新开始游戏
    private func resetValue() {
        timer.invalidate()
        clearAllBomb()
        clearAllRedPack()
        clearViewsOutSideScreen()
        // 重置值
        redPackClickedCount = 0
        runTimeTotal = 0
        timeCounter = 0
        redPackAllCount = 0
        bombAllCount = 0
        bombClickedCount = 0
    }

    /// 清除界面上所有红包
    public func clearAllRedPack() {
        for subview in subviews {
            if subview.tag == redPackCompomentTag {
                subview.layer.removeAllAnimations()
                subview.removeFromSuperview()
            }
        }
    }


    /// 清除界面上所有炸弹
    public func clearAllBomb() {
        for subview in subviews {
            if subview.tag == bombCompomentTag {
                subview.layer.removeAllAnimations()
                subview.removeFromSuperview()
            }
        }
    }


    // MARK: - 初始化设置
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
    /// 如果想改变轮播图片, 需要先停止播放,再改变播放
    /// imgView.stopAnimating()
    /// imgView.animationImages =  [...]
    /// imgView.startAnimating()
    public func setRedPack(
        images: [UIImage],
        size: CGSize? = nil,
        animationDuration: Double? = 1,
        intervalTime: Double = 0.5,
        dropDownTime: Double = 5,
        totalTime: Double = 15,
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
    
    /// 炸弹设置
    ///
    /// - Parameters:
    ///   - images: 炸弹图片集
    ///   - density: 密度,每x个红包就出现个炸弹
    ///   - clickHandle: 点击回调
    public func setBomb(images: [UIImage],
                        size: CGSize? = nil,
                        density: Int,
                        clickHandle: @escaping BombClickHandle) {
        bombClickHandle = clickHandle
        bombDensity = density
        bombImages = images
        bombSize = size
    }


    /// 红包雨结束总回调
    ///
    /// - Parameter completeHandle: 回调handle
    public func setCompleteHandle(handle: @escaping CompleteHandle) {
        self.completeHandle = handle
    }

    /// 红包出现的回调
    ///
    /// - Parameter completeHandle: 回调handle
    public func setRedPackAppearHandle(handle: @escaping RedPackAppearHandle) {
        self.redPackAppearHandle = handle
    }

    /// 炸弹出现的回调
    ///
    /// - Parameter completeHandle: 回调handle
    public func setBombAppearHandle(handle: @escaping BombAppearHandle) {
        self.bombAppearHandle = handle
    }


    /// 添加不可点击, 不可穿透的 view, 点击后会阻挡点击效果。
    /// 使用前先打开 clickPenetrateEnable 开关，否则不会执行任何操作。
    /// 注意：会改变 view 的 tag 值
    /// - Parameter views: 不想点击被穿透的 view 数组
    public func addNotPenetrateViews(views:[UIView]) {
        if clickPenetrateEnable {
            for view in views {
                view.tag = notPenetrateTag
            }
        }
    }

    /// 删除 View 的不可点击特性
    /// 使用前先打开 clickPenetrateEnable 开关，否则不会执行任何操作。
    /// 注意：会改变 view 的 tag 值
    /// - Parameter views: 去除不可点击穿透的 view 数组
    public func removeNotPenetrateViews(views:[UIView]) {
        if clickPenetrateEnable {
            for view in views {
                if view.tag == notPenetrateTag {
                    view.tag = 0
                }
            }
        }
    }
    
    // MARK: 私有方法
    @objc private func showRain() {
        runShowCount += 1
        guard Double(runShowCount) >= runShowFuncCount else {

            return
        }
        runTimeTotal += redPackIntervalTime // 执行时间
        runShowCount = 0 // 重置计数
        clearViewsOutSideScreen()
        let rest = self.restTime
        guard  rest > 0 else {
            endGame()
            return
        }

        timeCounter += 1
        show()
    }

    // 清屏, 把视野外的view去掉
    private func clearViewsOutSideScreen() {
        // 红包
        for repack in redPackList {
            removeCompoment(compoment: repack)
            if let index = redPackList.index(of: repack),
                repack.superview == nil {
                redPackList.remove(at: index)
            }
        }
        // 炸弹
        for bomb in bombList {
            removeCompoment(compoment: bomb)
            if let index = bombList.index(of: bomb),
                bomb.superview == nil {
                bombList.remove(at: index)
            }
        }
    }

    private func show() {
        // 红包
        let redPack = addRedPack()
        redPackAllCount += 1
        addAnimation(imageView: redPack)
        redPackList.append(redPack)
        redPackDidAppear(redPack: redPack)

        // 如果设了炸弹
        if bombDensity > 0 && redPackAllCount % bombDensity == 0{
            let bomb = addBomb()
            bombAllCount += 1
            addAnimation(imageView: bomb)
            bombList.append(bomb)
            bombDidAppear(bomb: bomb)
        }

    }

    // MARK: 生命周期
    /// 红包出现回调
    private func redPackDidAppear(redPack: UIImageView) {
        redPackAppearHandle?(redPack, redPackAllCount)
        delegate?.redpackDidAppear?(rainView: self, redpack: redPack, index: redPackAllCount)
    }

    /// 炸弹出现回调
    private func bombDidAppear(bomb: UIImageView) {
        bombAppearHandle?(bomb, bombAllCount)
        delegate?.bombDidAppear?(rainView: self, bomb: bomb, index: redPackAllCount)
    }

    /// 点击事件
    @objc func clicked(tapgesture: UITapGestureRecognizer) {
        let touchPoint = tapgesture.location(in: self)
        let views = self.subviews
        // 倒序, 从最上层view找起
        for viewTuple in views.enumerated().reversed() {
            // 判断界面内的红包的点击事件
            if viewTuple.element.layer.presentation()?
                .hitTest(touchPoint) != nil {
                if viewTuple.element.tag == redPackCompomentTag {
                    // 点到的是红包,马上结束
                    redPackClickedCount += 1
                    clickHandle?(self, viewTuple.element)
                    delegate?.redpackDidClicked?(rainView: self, redpack: viewTuple.element)
                    return
                } else if viewTuple.element.tag == bombCompomentTag {
                    // 如果是炸弹
                    bombClickedCount += 1
                    bombClickHandle?(self, viewTuple.element)
                    delegate?.bombDidClicked?(rainView: self, bomb: viewTuple.element)
                } else {
                    // 没开启点击穿透 或 点击 view 在不穿透列表中，则阻断点击
                    if !clickPenetrateEnable || viewTuple.element.tag == notPenetrateTag {
                        return
                    }
                }
            }
        }
    }


    // MARK: - 辅助函数
    // MARK:  暂停与恢复

    /// 恢复红包
    private func resumeRedPack() {
        for redpack in redPackList {
            resumeLayer(layer: redpack.layer)
        }
    }

    /// 恢复炸弹
    private func resumeBomb() {
        for redpack in bombList {
            resumeLayer(layer: redpack.layer)
        }
    }

    /// 暂停红包
    private func stopRedPack() {
        for i in 0..<redPackList.count {
            let imgView = redPackList[i]
            pauseLayer(layer: imgView.layer)
        }
    }

    /// 暂停炸弹
    private func stopBomb() {
        for i in 0..<bombList.count {
            let imgView = bombList[i]
            pauseLayer(layer: imgView.layer)
        }
    }

    // 暂停动画
    private func pauseLayer(layer: CALayer) {
        // notice: 不要乱调整代码顺序!
        // 时间回溯
        let off = layer.beginTime * CFTimeInterval(layer.speed)
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        let pausedTime = layer.convertTime(CACurrentMediaTime(), to: nil)
        layer.speed = 0.0
        layer.timeOffset = pausedTime - off
    }

    // 恢复动画
    private func resumeLayer(layer: CALayer) {
        let pausedTime = layer.timeOffset
        layer.speed = 1.0;
        layer.timeOffset = 0.0;
        layer.beginTime = 0.0;
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), to: nil) - pausedTime;
        layer.beginTime = timeSincePause;
    }

    private func addRedPack() -> UIImageView {
        let redPack = buildImageView(images: redPackImages, size: redPackSize)
        redPack.tag = redPackCompomentTag
        return redPack
    }

    private func addBomb() -> UIImageView {
        let bomb = buildImageView(images: bombImages, size: bombSize)
        bomb.tag = bombCompomentTag
        return bomb
    }

    private func buildImageView(images: [UIImage], size: CGSize?) -> UIImageView {
        //创建画布
        let imageView = UIImageView.init()
        imageView.image = images.first
        imageView.isUserInteractionEnabled = true
        if let duration = redPackAnimationDuration {
            imageView.animationDuration = duration
        }
        imageView.animationImages = images
        imageView.startAnimating()

        if let sizeTmp = size {
            imageView.frame.size = sizeTmp
        } else {
            imageView.sizeToFit()
        }
        let hidenDistance = max(imageView.frame.size.height, imageView.frame.size.width) * 2
        imageView.frame.origin = CGPoint(x: -hidenDistance, y: -hidenDistance)
        insertSubview(imageView, at: 0)
        return imageView
    }

    private func addAnimation(imageView: UIImageView) {
        let moveLayer = imageView.layer
        // 此处keyPath为CALayer的属性
        let  moveAnimation:CAKeyframeAnimation = CAKeyframeAnimation(keyPath:"position")
        // 动画路线，一个数组里有多个轨迹点
        moveAnimation.values = [NSValue(cgPoint: CGPoint(x: CGFloat(Float(arc4random_uniform(UInt32(frame.width)))), y: -imageView.frame.height)),NSValue(cgPoint: CGPoint(x:CGFloat(Float(arc4random_uniform(UInt32(frame.width)))), y: frame.height+10))]
        // 动画间隔
        moveAnimation.duration = redPackDropDownTime
        //重复次数
        moveAnimation.repeatCount = 1
        // 动画的速度
        moveAnimation.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionLinear)
        moveLayer.add(moveAnimation, forKey: "move")
    }

    private func removeCompoment(compoment: UIImageView) {
        if let aniFrame = compoment.layer.presentation()?.frame,
            aniFrame.isEmpty ||
            aniFrame.isNull ||
            !CGRect(x: frame.origin.x, y: frame.origin.y - aniFrame.height, width: frame.width, height: frame.height + aniFrame.height).intersects(aniFrame)  {
            compoment.removeFromSuperview()
        }

    }
}