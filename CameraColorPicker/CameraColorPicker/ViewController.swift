//
//  ViewController.swift
//  CameraColorPicker
//
//  Created by Zhe Qin on 2018/5/7.
//  Copyright © 2018年 Zhe Qin. All rights reserved.
//

import UIKit
import AVFoundation

let WIDTH = UIScreen.main.bounds.width
let HEIGHT = UIScreen.main.bounds.height
class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // 音视频采集会话
    let captureSession = AVCaptureSession()
    
    // 后置摄像头
    var backFacingCamera: AVCaptureDevice?
    
    // 当前正在使用的设备
    var currentDevice: AVCaptureDevice?
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        guard let baseAddr = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
            return
        }
        let width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bimapInfo: CGBitmapInfo = [
            .byteOrder32Little,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)]
        
        guard let content = CGContext(data: baseAddr, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bimapInfo.rawValue) else {
            return
        }
        
        guard let cgImage = content.makeImage() else {
            return
        }
        
        DispatchQueue.main.async {
            self.previewLayer.contents = cgImage
            let color = self.previewLayer.pickColor(at: self.center)
            self.view.backgroundColor = color
            self.lineShape.strokeColor = color?.cgColor
        }
        
    }
    let previewLayer = CALayer()
    let lineShape = CAShapeLayer()
    
    func setupUI() {
        previewLayer.bounds = CGRect(x: 0, y: 0, width: WIDTH-30, height: WIDTH-30)
        previewLayer.position = view.center
        previewLayer.contentsGravity = kCAGravityResizeAspectFill
        previewLayer.masksToBounds = true
        previewLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)))
        view.layer.insertSublayer(previewLayer, at: 0)
        
        //圆环
        let linePath = UIBezierPath.init(ovalIn: CGRect.init(x: 0, y: 0, width: 40, height: 40))
        lineShape.frame = CGRect.init(x: WIDTH/2-20, y:HEIGHT/2-20, width: 40, height: 40)
        lineShape.lineWidth = 5
        lineShape.strokeColor = UIColor.red.cgColor
        lineShape.path = linePath.cgPath
        lineShape.fillColor = UIColor.clear.cgColor
        self.view.layer.insertSublayer(lineShape, at: 1)
        
        //圆点
        let linePath1 = UIBezierPath.init(ovalIn: CGRect.init(x: 0, y: 0, width: 8, height: 8))
        let lineShape1 = CAShapeLayer()
        lineShape1.frame = CGRect.init(x: WIDTH/2-4, y:HEIGHT/2-4, width: 8, height: 8)
        lineShape1.path = linePath1.cgPath
        lineShape1.fillColor = UIColor.init(white: 0.7, alpha: 0.5).cgColor
        self.view.layer.insertSublayer(lineShape1, at: 1)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        //获取设备，创建UI
        self.CreateUI()
    }
    
    // 相机数据帧接收队列
    let queue = DispatchQueue(label: "com.camera.video.queue")
    
    // 取色位置
    var center: CGPoint = CGPoint(x: WIDTH/2-15, y: WIDTH/2-15)
    //MARK: - 获取设备,创建自定义视图
    func CreateUI(){
        // 将音视频采集会话的预设设置为高分辨率照片--选择照片分辨率
        self.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        // 获取设备
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                self.backFacingCamera = device
            }
        }
        
        //设置当前设备为前置摄像头
        self.currentDevice = self.backFacingCamera
        do {
            // 当前设备输入端
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentDevice!)
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: NSNumber(value: kCMPixelFormat_32BGRA)] as! [String : Any]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            
            if self.captureSession.canAddOutput(videoOutput) {
                self.captureSession.addOutput(videoOutput)
            }
            self.captureSession.addInput(captureDeviceInput)
        } catch {
            print(error)
            return
        }
        
        // 启动音视频采集的会话
        self.captureSession.startRunning()
    }
}

public extension CALayer {
    
    /// 获取特定位置的颜色
    ///
    /// - parameter at: 位置
    ///
    /// - returns: 颜色
    public func pickColor(at position: CGPoint) -> UIColor? {
        
        // 用来存放目标像素值
        var pixel = [UInt8](repeatElement(0, count: 4))
        // 颜色空间为 RGB，这决定了输出颜色的编码是 RGB 还是其他（比如 YUV）
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // 设置位图颜色分布为 RGBA
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }
        // 设置 context 原点偏移为目标位置所有坐标
        context.translateBy(x: -position.x, y: -position.y)
        // 将图像渲染到 context 中
        render(in: context)
        
        return UIColor(red: CGFloat(pixel[0]) / 255.0,
                       green: CGFloat(pixel[1]) / 255.0,
                       blue: CGFloat(pixel[2]) / 255.0,
                       alpha: CGFloat(pixel[3]) / 255.0)
    }
}
