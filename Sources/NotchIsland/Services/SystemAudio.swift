import AudioToolbox
import CoreAudio
import Foundation

/// Output volume, mute and output device, driven by CoreAudio property listeners (no polling).
final class SystemAudio: ObservableObject {
    @Published private(set) var volume: Float = 0
    @Published private(set) var isMuted = false
    @Published private(set) var outputName = ""
    @Published private(set) var outputSymbol = "speaker.wave.2.fill"

    var onVolumeChange: ((Float, Bool) -> Void)?
    var onOutputChange: ((String, String) -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?
    private var ready = false

    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    init() {
        attachToDefaultDevice(announce: false)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.attachToDefaultDevice(announce: true)
        }
        // Ignore the burst of callbacks that can happen right after launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.ready = true }
    }

    func setVolume(_ value: Float) {
        var v = min(max(value, 0), 1)
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &volumeAddress, 0, nil, size, &v)
        if isMuted && v > 0 {
            var off: UInt32 = 0
            AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &off)
        }
    }

    func toggleMute() {
        var value: UInt32 = isMuted ? 0 : 1
        AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private func attachToDefaultDevice(announce: Bool) {
        // Detach listeners from the old device.
        if deviceID != kAudioObjectUnknown {
            if let block = volumeListener { AudioObjectRemovePropertyListenerBlock(deviceID, &volumeAddress, DispatchQueue.main, block) }
            if let block = muteListener { AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, block) }
        }

        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown
        else { return }
        let changed = id != deviceID
        deviceID = id

        let volumeBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.readLevels(announce: true) }
        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.readLevels(announce: true) }
        AudioObjectAddPropertyListenerBlock(id, &volumeAddress, DispatchQueue.main, volumeBlock)
        AudioObjectAddPropertyListenerBlock(id, &muteAddress, DispatchQueue.main, muteBlock)
        volumeListener = volumeBlock
        muteListener = muteBlock

        readLevels(announce: false)
        let name = deviceName(id)
        outputName = name
        outputSymbol = symbol(for: name, transport: transportType(id))
        if announce && changed && ready { onOutputChange?(name, outputSymbol) }
    }

    private func readLevels(announce: Bool) {
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &v) == noErr {
            if volume != v { volume = v }
        }
        var m: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &size, &m) == noErr {
            if isMuted != (m != 0) { isMuted = m != 0 }
        }
        if announce && ready { onVolumeChange?(volume, isMuted) }
    }

    private func deviceName(_ id: AudioObjectID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let value = name?.takeRetainedValue() else { return "Speakers" }
        return value as String
    }

    private func transportType(_ id: AudioObjectID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        return value
    }

    private func symbol(for name: String, transport: UInt32) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpods.pro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE { return "headphones" }
        if transport == kAudioDeviceTransportTypeBuiltIn { return lower.contains("headphone") ? "headphones" : "laptopcomputer" }
        if transport == kAudioDeviceTransportTypeAirPlay { return "airplayaudio" }
        if transport == kAudioDeviceTransportTypeHDMI || transport == kAudioDeviceTransportTypeDisplayPort { return "tv" }
        return "hifispeaker.fill"
    }
}
