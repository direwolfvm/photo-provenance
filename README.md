
# PhotoSeal

PhotoSeal is an offline first iOS camera application that creates tamper evident, cryptographically signed provenance metadata for photos at the moment of capture.

It uses the C2PA standard to embed a signed manifest into the image or export it as a portable sidecar file. Verification works without any PhotoSeal servers and without network connectivity.

The app is designed for consumers who want durable proof that a photo has not been altered after capture, while preserving privacy and remaining usable in disconnected environments.

## What PhotoSeal does

* Captures photos using AVFoundation
* Generates a C2PA manifest at capture time
* Cryptographically binds the manifest to the image content
* Signs the manifest using a Secure Enclave backed key when available
* Embeds the manifest into the image or exports a `.c2pa` sidecar
* Optionally adds a trusted timestamp when the user is online
* Verifies provenance entirely offline

## What PhotoSeal does not do

* It does not prove that a photo depicts reality
* It does not prevent edits or deletion
* It does not identify a specific device or user
* It does not require or depend on any backend service

PhotoSeal provides tamper evidence, not immutability or truth verification.

## Security model

PhotoSeal follows a layered trust model:

### Offline guarantees

When offline, PhotoSeal guarantees:

* The photo content has not changed since signing
* The manifest has not been modified
* The signature matches the embedded public key

This works without any network access or trust in PhotoSeal infrastructure.

What offline verification cannot guarantee:

* That the signing key is hardware backed
* That the OS or device was uncompromised
* That the capture time is accurate

These limits are inherent to consumer iOS platforms.

### Optional online upgrades

When online, users may opt into additional trust anchors:

* RFC 3161 trusted timestamps
* App policy enforcement
* Future transparency log support

These upgrades enhance verification without changing the offline guarantees.

## C2PA alignment

PhotoSeal uses the C2PA (Coalition for Content Provenance and Authenticity) standard:

* Each photo contains a signed C2PA claim
* Standard assertions are included (`c2pa.actions`, `schema.org`)
* Capture specific metadata is stored in a custom assertion namespace
* Required C2PA hard binding protects the asset
* Manifests can be embedded or stored as `.c2pa` sidecars

Any C2PA compatible verifier can validate PhotoSeal output.

## Repository structure

```
PhotoSeal/
├── PhotoSealApp/        SwiftUI application
├── PhotoSealCore/       Core signing and provenance logic
│   ├── CameraCapture.swift
│   ├── PixelCanonicalizer.swift
│   ├── CaptureAssertion.swift
│   ├── C2PAManifestBuilder.swift
│   ├── C2PAEmbedder.swift
│   ├── SidecarManager.swift
│   └── Verifier.swift
├── Schemas/
│   ├── org.photoseal.capture.v1.schema.json
│   └── PhotoSeal.c2pa-manifest-definition.v1.json
├── Tests/
└── README.md
```

## How PhotoSeal works

1. Capture
   A photo is captured using AVFoundation.

2. Canonicalization
   The image is decoded, orientation applied, converted to sRGB RGBA8, and hashed.

3. Manifest construction
   A C2PA manifest definition is created containing:

   * Standard C2PA assertions
   * A PhotoSeal custom capture assertion
   * Required hard binding handled by the C2PA SDK

4. Signing
   The manifest is signed using a locally generated ECDSA P-256 key. When available, keys are backed by Secure Enclave.

5. Embedding and export
   The C2PA manifest store is embedded into the image when possible. A `.c2pa` sidecar is always supported.

6. Optional notarization
   When enabled and online, a trusted timestamp is added and recorded as a new manifest entry.

## Verification

Verification checks:

* Manifest signature validity
* Hard binding integrity
* Optional timestamp validity

Verification does not require PhotoSeal servers and works offline.

## Key management

* Keys are generated per app install
* Keys are stored locally and never uploaded
* Reinstalling the app creates a new signing identity
* Old photos remain verifiable

This design avoids device tracking and preserves user privacy.

## Limitations

* Jailbroken or compromised devices cannot be reliably detected offline
* Image edits invalidate the manifest by design
* Metadata stripping may remove embedded manifests, use sidecars for portability
* iCloud Photos and social platforms may recompress images

These are platform constraints, not implementation flaws.

## Why C2PA

C2PA provides:

* A standardized provenance container
* Strong cryptographic binding to assets
* Interoperable verification tools
* Long term ecosystem support

PhotoSeal uses C2PA as intended, without inventing a parallel format.

## Building the project

Requirements:

* Xcode 15+
* iOS 17+
* Swift 5.9+

Clone and open the Swift package in Xcode:

```
git clone https://github.com/your-org/photoseal.git
open Package.swift
```

No backend services are required.

## License

TBD

## Status

This project is experimental and intended for research and early adoption use cases. APIs and schemas may evolve.

## Acknowledgements

* Coalition for Content Provenance and Authenticity (C2PA)
* Content Authenticity Initiative (CAI)
* Apple AVFoundation and CryptoKit teams
