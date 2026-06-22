//
//  PhotoComponents.swift
//  RoofScan
//
//  Photo thumbnail, UIImagePickerController bridge, and a reusable
//  "attach photo" field that saves into PhotoStore.
//

import SwiftUI
import UIKit

// MARK: - Thumbnail

struct PhotoThumb: View {
    let filename: String?
    var size: CGFloat = 64
    var corner: CGFloat = 12

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.34))
                    .foregroundColor(Theme.textDisabled)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.bgSoft)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .onAppear { image = PhotoStore.shared.load(filename) }
        .onChange(of: filename) { new in image = PhotoStore.shared.load(new) }
    }
}

// MARK: - UIImagePickerController bridge

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    let onPicked: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onPicked(img) }
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Attach photo field

struct PhotoPickerField: View {
    @Binding var filename: String?

    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showSourceChoice = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo (pinned to this point)")
                .font(.rsCaption()).foregroundColor(Theme.textSecondary)
            HStack(spacing: 14) {
                PhotoThumb(filename: filename, size: 76)
                VStack(spacing: 8) {
                    SecondaryButton(title: filename == nil ? "Add photo" : "Replace", icon: "camera.fill") {
                        if cameraAvailable { showSourceChoice = true } else { showLibrary = true }
                    }
                    if filename != nil {
                        Button {
                            PhotoStore.shared.delete(filename)
                            filename = nil
                        } label: {
                            Text("Remove").font(.rsCaption()).foregroundColor(Theme.critical)
                        }
                    }
                }
            }
        }
        .actionSheet(isPresented: $showSourceChoice) {
            ActionSheet(title: Text("Add photo"), buttons: [
                .default(Text("Camera")) { showCamera = true },
                .default(Text("Photo library")) { showLibrary = true },
                .cancel()
            ])
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(sourceType: .photoLibrary) { img in save(img) }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { img in save(img) }
        }
    }

    private func save(_ img: UIImage) {
        if let newName = PhotoStore.shared.save(img) {
            PhotoStore.shared.delete(filename)
            filename = newName
        }
    }
}
