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
    @IBOutlet private var tfMensagem: UITextField!
    @IBOutlet private var btnEnviar: UIButton!
    @IBOutlet private var viewAudioTimer: UIView!
    @IBOutlet private var viewDeslizarBtn: UIStackView!
    @IBOutlet private var btnEnviarLongPressGesture: UILongPressGestureRecognizer!
    @IBOutlet private var btnEnviarPanGesture: UIPanGestureRecognizer!
    @IBOutlet private var btnEnviarWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var btnEnviarHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var btnEnviarTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private var ivAudioMic: UIImageView!
    @IBOutlet private var lbAudioTimer: UILabel!
    @IBOutlet private var containerViewBottomConstraint: NSLayoutConstraint!
    
    var audioDurationInSecs = 0
    var audioTimer: Timer?
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var audioFilename = ""
    var audioPlayer: AVPlayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerKeyboardNotifications()
        // Setting up AudioSession
        recordingSession = AVAudioSession.sharedInstance()
        AVAudioSession.sharedInstance().requestRecordPermission { (hasPermission) in
            if hasPermission {}
        }
        
        btnEnviarLongPressGesture.delegate = self
        
        tfMensagem.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        tfMensagem.placeholder = "Digite aqui..."
        btnEnviar.backgroundColor = .green
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

    @objc func textFieldDidChange() {
        let mensagem = tfMensagem.text ?? ""
        if mensagem.isEmpty {
            btnEnviar.setImage(UIImage(named: "Botao Mic"), for: .normal)
            btnEnviarLongPressGesture.isEnabled = true
            btnEnviarPanGesture.isEnabled = true
        } else {
            btnEnviar.setImage(UIImage(named: "Botao Enviar"), for: .normal)
            btnEnviarLongPressGesture.isEnabled = false
            btnEnviarPanGesture.isEnabled = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: Delegate LongPress gesture do botão enviar
extension ViewController : UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return (gestureRecognizer == btnEnviarLongPressGesture && otherGestureRecognizer == btnEnviarPanGesture)
    }
}

// MARK: Gravação de áudio
extension ViewController : AVAudioRecorderDelegate {
    func updateUi(recording: Bool) {
        UIView.animate(withDuration: 0.3, animations: {
            if recording {
                self.btnEnviarWidthConstraint.constant = 45
                self.btnEnviarHeightConstraint.constant = 45
                self.view.layoutIfNeeded()
                self.btnEnviar.layer.cornerRadius = 22.5
            } else {
                self.btnEnviarWidthConstraint.constant = 35
                self.btnEnviarHeightConstraint.constant = 35
                self.view.layoutIfNeeded()
                self.btnEnviar.layer.cornerRadius = 17.5
            }
            
            self.viewAudioTimer.isHidden = !recording
            self.viewDeslizarBtn.isHidden = !recording
            
            self.tfMensagem.isHidden = recording
        })
    }
    
    @objc func updateAudioTimer() {
        audioDurationInSecs += 1
        let minutes = Int(floor(Double(audioDurationInSecs / 60)))
        
        UIView.animate(withDuration: 0.3) {
            let alpha = self.ivAudioMic.alpha
            
            self.ivAudioMic.alpha = alpha == 0 ? 1 : 0
        }
        
        lbAudioTimer.text = "\(minutes):\(String(format: "%02d", audioDurationInSecs % 60))"
    }
    
    @IBAction func btnEnviarLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began { // Botão de enviar está sendo pressionado, começar a gravar áudio
            updateUi(recording: true)
            startAudioTimer()
            startRecording()
        } else if sender.state == .ended { // Botão de enviar foi solto, parar gravação
            updateUi(recording: false)
            stopRecording()
            enviarAudio()
            stopAudioTimer()
        } else if sender.state == .cancelled { // Botão de enviar foi cancelado, cancelar gravação
            stopAudioTimer()
            cancelRecording()
            updateUi(recording: false)
        }
    }
    
    @IBAction func btnEnviarPan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self.view)
        
        // Só habilitar gesto de deslizar quando o botão estiver sendo pressionado
        if sender.view != nil && btnEnviarLongPressGesture.state == .changed {
            btnEnviarTrailingConstraint.constant = btnEnviarTrailingConstraint.constant - translation.x
            
            let porcentagem = 100 * (btnEnviarTrailingConstraint.constant / self.view.frame.width)
            
            if porcentagem > 30 {
                stopAudioTimer()
            }
        }
        
        sender.setTranslation(CGPoint.zero, in: self.view)
    }
    
    func stopAudioTimer() {
        if audioTimer != nil {
            btnEnviarLongPressGesture.isEnabled = false
            btnEnviarPanGesture.isEnabled = false
            
            UIView.animate(withDuration: 1, animations: {
                self.btnEnviarTrailingConstraint.constant = 5
            })
            
            audioTimer?.invalidate()
            audioDurationInSecs = 0
            lbAudioTimer.text = "0:00"
            audioTimer = nil
            
            btnEnviarPanGesture.isEnabled = true
            btnEnviarLongPressGesture.isEnabled = true
        }
    }
    
    func startAudioTimer() {
        audioTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateAudioTimer),
            userInfo: nil,
            repeats: true)
    }
    
    
    func startRecording() {
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
    
    func stopRecording() {
        print("Stopped recording...")
        audioRecorder.stop()
        audioRecorder = nil
    }
    
    func cancelRecording() {
        stopRecording()
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        let url = documentDirectory.appendingPathComponent("\(audioFilename).m4a")
        
        do {
            print("Excluindo áudio -> \(audioFilename).m4a")
            try FileManager.default.removeItem(at: url)
        } catch {
            print(error)
        }
    }
    
    func enviarAudio() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        let url = documentDirectory.appendingPathComponent("\(audioFilename).m4a")
    }
}
