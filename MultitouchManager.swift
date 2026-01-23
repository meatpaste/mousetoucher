import Foundation
import CoreGraphics
import AppKit

// Swift wrapper for Multitouch framework
class MultitouchManager {
    private var devices: [MTDeviceRef] = []
    private var tapDetector = TapDetector(tapTimeThreshold: 0.25, tapMovementThreshold: 0.08)
    private var isEnabled = true
    private var activeTouch: Int32 = -1
    private var touchStartX: Float = 0.0
    private var touchStartY: Float = 0.0
    private var rightClickThreshold: Float = 0.6  // X > 0.6 = right side
    private var surfaceMovementThreshold: Float = 0.15  // Max finger movement on surface (0-1 scale)

    fileprivate static var sharedInstance: MultitouchManager?

    var onClickSynthesized: ((CGPoint, Bool) -> Void)?

    init() {
        MultitouchManager.sharedInstance = self
    }

    func start() {
        guard let deviceList = MTDeviceCreateList() else {
            return
        }

        let deviceArray = deviceList.takeRetainedValue() as NSArray
        let count = CFArrayGetCount(deviceArray)

        for i in 0..<count {
            let device = unsafeBitCast(CFArrayGetValueAtIndex(deviceArray, i), to: MTDeviceRef.self)

            // Only monitor external devices (Magic Mouse), skip built-in trackpads
            let isBuiltIn = MTDeviceIsBuiltIn(device)

            if !isBuiltIn {
                devices.append(device)
                MTRegisterContactFrameCallback(device, touchCallback)
                MTDeviceStart(device, 0)
            }
        }
    }

    func stop() {
        for device in devices {
            MTUnregisterContactFrameCallback(device, touchCallback)
            MTDeviceStop(device)
        }
        devices.removeAll()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func processTouches(_ touches: UnsafeMutablePointer<MTTouch>, numTouches: Int, timestamp: Double) {
        guard isEnabled else { return }

        // Security: Validate input to prevent buffer overflows and invalid touch counts
        guard numTouches >= 0 && numTouches <= 10 else { return }

        if numTouches == 0 {
            if activeTouch != -1 {
                // Get cursor position directly from CGEvent (already in correct coordinate space)
                let cgLocation = CGEvent(source: nil)?.location ?? CGPoint.zero

                if let tapLocation = tapDetector.touchEnded(at: cgLocation) {
                    let isRightClick = touchStartX > rightClickThreshold
                    onClickSynthesized?(tapLocation, isRightClick)
                }
                activeTouch = -1
                touchStartX = 0.0
                touchStartY = 0.0
            }
            return
        }

        if numTouches == 1 {
            let touch = touches[0]
            // Get cursor position directly from CGEvent (already in correct coordinate space)
            let cgLocation = CGEvent(source: nil)?.location ?? CGPoint.zero

            if touch.state == 4 || touch.state == 7 {
                if activeTouch == -1 {
                    // New touch started - record starting position on surface
                    activeTouch = touch.identifier
                    touchStartX = touch.normalized.position.x
                    touchStartY = touch.normalized.position.y
                    tapDetector.touchBegan(at: cgLocation)
                } else if activeTouch == touch.identifier {
                    // Same touch continuing - check if finger moved too much on surface (scrolling)
                    let deltaX = abs(touch.normalized.position.x - touchStartX)
                    let deltaY = abs(touch.normalized.position.y - touchStartY)
                    let surfaceMovement = max(deltaX, deltaY)

                    if surfaceMovement > surfaceMovementThreshold {
                        // Finger moved too much on surface - likely scrolling, cancel tap
                        tapDetector.reset()
                        activeTouch = -1
                        touchStartX = 0.0
                        touchStartY = 0.0
                    } else {
                        // Check cursor movement too
                        let moved = tapDetector.touchMoved(to: cgLocation)
                        if moved {
                            activeTouch = -1
                            touchStartX = 0.0
                            touchStartY = 0.0
                        }
                    }
                }
            }
        } else if numTouches > 1 {
            if activeTouch != -1 {
                tapDetector.reset()
                activeTouch = -1
                touchStartX = 0.0
                touchStartY = 0.0
            }
        }
    }

    deinit {
        stop()
        // Security: Properly release device references to prevent resource leaks
        for device in devices {
            MTDeviceRelease(device)
        }
        devices.removeAll()
    }
}

private func touchCallback(device: Int32, touches: UnsafeMutablePointer<MTTouch>?, numTouches: Int32, timestamp: Double, frame: Int32) -> Int32 {
    if let manager = MultitouchManager.sharedInstance, let touches = touches {
        manager.processTouches(touches, numTouches: Int(numTouches), timestamp: timestamp)
    }
    return 0
}
