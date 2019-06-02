//
//  ViewController.swift
//  HoldRecordButton
//
//  Created by Matheus Fróes on 08/05/19.
//  Copyright © 2019 Matheus Fróes. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet private var textField: UITextField!
    @IBOutlet private var sendButton: UIButton!
    @IBOutlet private var viewAudioTimer: UIView!
    @IBOutlet private var slideToCancelView: UIStackView!
    @IBOutlet private var sendButtonLongPressGesture: UILongPressGestureRecognizer!
    @IBOutlet private var sendButtonPanGesture: UIPanGestureRecognizer!
    @IBOutlet private var sendButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var sendButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var sendButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private var ivAudioMic: UIImageView!
    @IBOutlet private var lbAudioTimer: UILabel!
    @IBOutlet private var containerViewBottomConstraint: NSLayoutConstraint!
    
    private var audioDurationInSecs = 0
    private var audioTimer: Timer?
    private var recordingSession: AVAudioSession!
    private var audioRecorder: AVAudioRecorder!
    private var audioFilename = ""
    private var audioPlayer: AVPlayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerKeyboardNotifications()
        
        // Setting up AudioSession
        recordingSession = AVAudioSession.sharedInstance()
        AVAudioSession.sharedInstance().requestRecordPermission { (hasPermission) in
            if hasPermission {}
        }
        
        sendButtonLongPressGesture.delegate = self
        
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        textField.placeholder = "Type a message"
        sendButton.backgroundColor = .blue
    }
    
    private func registerKeyboardNotifications() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil) { [weak self] notification in
            if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                let keyboardRectangle = keyboardFrame.cgRectValue
                let keyboardHeight = keyboardRectangle.height
                self?.containerViewBottomConstraint.constant = keyboardHeight
                self?.view.layoutIfNeeded()
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil) { [weak self] _ in
            self?.containerViewBottomConstraint.constant = 0
            self?.view.layoutIfNeeded()
        }
    }

    @objc private func textFieldDidChange() {
        let mensagem = textField.text ?? ""
        if mensagem.isEmpty {
            sendButton.setImage(UIImage(named: "microphone_button"), for: .normal)
            sendButtonLongPressGesture.isEnabled = true
            sendButtonPanGesture.isEnabled = true
        } else {
            sendButton.setImage(UIImage(named: "send_button"), for: .normal)
            sendButtonLongPressGesture.isEnabled = false
            sendButtonPanGesture.isEnabled = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: Send button long press gesture delegate
extension ViewController : UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return (gestureRecognizer == sendButtonLongPressGesture && otherGestureRecognizer == sendButtonPanGesture)
    }
}

// MARK: Audio recorder delegate
extension ViewController : AVAudioRecorderDelegate {
    private func updateInterface(recording: Bool) {
        UIView.animate(withDuration: 0.3, animations: {
            if recording {
                self.sendButtonWidthConstraint.constant = 45
                self.sendButtonHeightConstraint.constant = 45
                self.view.layoutIfNeeded()
                self.sendButton.layer.cornerRadius = 22.5
            } else {
                self.sendButtonWidthConstraint.constant = 35
                self.sendButtonHeightConstraint.constant = 35
                self.view.layoutIfNeeded()
                self.sendButton.layer.cornerRadius = 17.5
            }
            
            self.viewAudioTimer.isHidden = !recording
            self.slideToCancelView.isHidden = !recording
            
            self.textField.isHidden = recording
        })
    }
    
    @IBAction private func sendButtonLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began { // Send button is being pressed, start recording
            updateInterface(recording: true)
            startAudioTimer()
            startRecording()
        } else if sender.state == .ended { // Send button was released, stop recording
            updateInterface(recording: false)
            stopRecording()
            sendAudio()
            stopAudioTimer()
        } else if sender.state == .cancelled { // Send button long press gesture was cancelled, cancel recording
            stopAudioTimer()
            cancelRecording()
            updateInterface(recording: false)
        }
    }
    
    @IBAction private func sendButtonPanGesture(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self.view)
        
        // Enable pan gesture only if the send button is being pressed
        if sender.view != nil && sendButtonLongPressGesture.state == .changed {
            sendButtonTrailingConstraint.constant = sendButtonTrailingConstraint.constant - translation.x
            
            let percentage = 100 * (sendButtonTrailingConstraint.constant / self.view.frame.width)
            
            if percentage > 30 {
                stopAudioTimer()
            }
        }
        
        sender.setTranslation(.zero, in: self.view)
    }
    
    private func stopAudioTimer() {
        if audioTimer != nil {
            sendButtonLongPressGesture.isEnabled = false
            sendButtonPanGesture.isEnabled = false
            
            UIView.animate(withDuration: 1, animations: {
                self.sendButtonTrailingConstraint.constant = 5
            })
            
            audioTimer?.invalidate()
            audioDurationInSecs = 0
            lbAudioTimer.text = "0:00"
            audioTimer = nil
            
            sendButtonPanGesture.isEnabled = true
            sendButtonLongPressGesture.isEnabled = true
        }
    }
    
    private func startAudioTimer() {
        audioTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateAudioTimer),
            userInfo: nil,
            repeats: true)
    }
    
    @objc private func updateAudioTimer() {
        audioDurationInSecs += 1
        let minutes = Int(floor(Double(audioDurationInSecs / 60)))
        
        UIView.animate(withDuration: 0.3) {
            let alpha = self.ivAudioMic.alpha
            
            self.ivAudioMic.alpha = alpha == 0 ? 1 : 0
        }
        
        lbAudioTimer.text = "\(minutes):\(String(format: "%02d", audioDurationInSecs % 60))"
    }
    
    private func startRecording() {
        if audioRecorder == nil {
            audioFilename = UUID().uuidString
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentDirectory = paths[0]
            let filename = documentDirectory.appendingPathComponent("\(audioFilename).m4a")
            
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue]
            
            do {
                audioRecorder = try AVAudioRecorder(url: filename, settings: settings)
                audioRecorder.delegate = self
                
                let recording = audioRecorder.record()
                print("Recording audio = \(recording)")
            } catch {
                print(error)
            }
        }
    }
    
    private func stopRecording() {
        print("Stopped recording...")
        audioRecorder.stop()
        audioRecorder = nil
    }
    
    private func cancelRecording() {
        stopRecording()
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        let url = documentDirectory.appendingPathComponent("\(audioFilename).m4a")
        
        do {
            print("Removing audio -> \(audioFilename).m4a")
            try FileManager.default.removeItem(at: url)
        } catch {
            print(error)
        }
    }
    
    private func sendAudio() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        _ = documentDirectory.appendingPathComponent("\(audioFilename).m4a")
    }
}
