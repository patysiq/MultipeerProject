//
//  ViewController.swift
//  MultiPeerImage
//
//  Created by PATRICIA S SIQUEIRA on 20/07/23.
//

import UIKit
import AVFoundation
import Combine
import Foundation
import MultipeerConnectivity

enum ImageSource {
    case photoLibrary
    case camera
}

class ViewController: UICollectionViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    var images = [UIImage]()
    var imageType = ""
    var imagesDataType = [Data?]()
    var peerID = MCPeerID(displayName: UIDevice.current.name)
    var mcSession: MCSession?
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    
    var isHeicSupported: Bool {
        (CGImageDestinationCopyTypeIdentifiers() as! [String]).contains("public.heic")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Image Share"
        
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = 10
        let connectedPeersButton = UIBarButtonItem(title: "All Devices", style: .plain, target: self, action: #selector(connectedPeers))
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt))

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
        navigationItem.leftBarButtonItems = [addButton, spacer, connectedPeersButton]
        
        
        let pngImageButton = UIBarButtonItem(title: "PNG", style: .plain, target: self, action: #selector(pngConfig))
        let jpegImageButton = UIBarButtonItem(title: "JPEG", style: .plain, target: self, action: #selector(jpegConfig))
        let heicImageButton = UIBarButtonItem(title: "HEIC", style: .plain, target: self, action: #selector(heicConfig))
        
        toolbarItems = [pngImageButton, jpegImageButton, heicImageButton]
        
        navigationController?.isToolbarHidden = false
        
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
    }
    
    // MARK: Collection Methods
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageView", for: indexPath)
        
        if let imageView = cell.viewWithTag(1000) as? UIImageView {
            imageView.image = images[indexPath.item]
        }
        
        if let imageName = cell.viewWithTag(1001) as? UILabel {
            imageName.text = imagesDataType[indexPath.item]?.fileExtension
        }
        
        return cell
    }
    
    // MARK: objc Methods
    
    @objc func connectedPeers() {
        guard let mcSession = mcSession else { return }
        
        var devicesList = [String]()
        
        for peer in mcSession.connectedPeers {
            devicesList.append(peer.displayName)
        }
        
        var message = devicesList.joined(separator: "\n")
        
        if devicesList.count == 0 {
            message = "No devices are connected."
        }
        
        let ac = UIAlertController(title: "All Devices", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }
    
    @objc func showConnectionPrompt() {
        let ac = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
        ac.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    @objc func importPicture() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            selectImageFrom(.photoLibrary)
            return
        }
        selectImageFrom(.camera)
    }
    
    @objc func pngConfig() {
        title = "PNG Image Share"
        imageType = "PNG"
    }
    
    @objc func jpegConfig() {
        title = "JPEG Image Share"
        imageType = "JPEG"
    }
    
    @objc func heicConfig() {
        if isHeicSupported {
            title = "HEIC Image Share"
            imageType = "HEIC"
        } else {
            let ac = UIAlertController(title: "Not supported", message: "Change Format", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            jpegConfig()
        }
    }
    
    func selectImageFrom(_ source: ImageSource) {
        let picker =  UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        
        switch source {
        case .camera:
            picker.sourceType = .camera
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        }
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let image = info[.editedImage] as? UIImage else { return }
        var imageData: Data?
        
        dismiss(animated: true)
        
        images.insert(image, at: 0)
        collectionView.reloadData()
        
        
        switch imageType {
        case "PGN":
            imageData = image.pngData()
        case "JPEG":
            imageData = image.jpegData(compressionQuality: 0.3)
        case "HEIC":
            do {
                imageData = try image.heicData(compressionQuality: 0.3)
            } catch let error as NSError {
                let ac = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                present(ac, animated: true)
            }
            
        default:
            imageData = image.pngData()
        }
        imagesDataType.insert(imageData, at: 0)
        sendImage(imageData, imageType)
    }
    
    func sendImage(_ imageData: Data?, _ imageFormat: String) {
        guard let mcSession = mcSession else { return }
        if mcSession.connectedPeers.count > 0 {
            if let data = imageData {
                do {
                    try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    let ac = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    present(ac, animated: true)
                }
            }
        }
    }
    
    // MARK: Start and Accept Connections
    
    func startHosting(action: UIAlertAction!) {
        guard let mcSession = mcSession else { return }
        mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "imageSharePOC", discoveryInfo: nil, session: mcSession)
        mcAdvertiserAssistant.start()
    }
    
    func joinSession(action: UIAlertAction!) {
        guard let mcSession = mcSession else { return }
        let mcBrowser = MCBrowserViewController(serviceType: "imageSharePOC", session: mcSession)
        mcBrowser.delegate = self
        present(mcBrowser, animated: true, completion: nil)
    }
    
}

extension ViewController: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        switch state {
        case MCSessionState.connected:
            print("Connected: \(peerID.displayName)")
            
        case MCSessionState.connecting:
            print("Connecting: \(peerID.displayName)")
            
        case MCSessionState.notConnected:
            let ac = UIAlertController(title: "\(peerID.displayName) has disconnected", message: nil, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(ac, animated: true, completion: nil)
            print("Not Connected: \(peerID.displayName)")
            
        @unknown default:
            print("Unknown state received: \(peerID.displayName)")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            if let image = UIImage(data: data) {
                self?.images.insert(image, at: 0)
                self?.imagesDataType.insert(data, at: 0)
                self?.collectionView.reloadData()
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
}

extension ViewController: MCBrowserViewControllerDelegate {
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
    }
    
}
