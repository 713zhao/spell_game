#!/usr/bin/env python3
"""
Generate minimal test audio files for the Spell Adventure game.

This script creates simple WAV files for testing sound effects.
These are placeholder files - replace with professional audio for production.

Requirements:
    pip install pydub

Usage:
    python generate_test_sounds.py
"""

import os
import wave
import struct
import math

def generate_tone(frequency, duration_ms, sample_rate=22050):
    """Generate a simple sine wave tone."""
    num_samples = int(sample_rate * duration_ms / 1000)
    amplitude = 32767  # Max amplitude for 16-bit audio

    samples = []
    for i in range(num_samples):
        sample = amplitude * math.sin(2 * math.pi * frequency * i / sample_rate)
        samples.append(int(sample))

    return samples

def write_wav(filename, samples, sample_rate=22050):
    """Write samples to a WAV file."""
    os.makedirs('assets/sounds', exist_ok=True)
    filepath = os.path.join('assets/sounds', filename)

    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)

        for sample in samples:
            wav_file.writeframes(struct.pack('<h', sample))

    print(f"Created: {filepath}")

def main():
    """Generate all test sound files."""
    print("Generating test audio files...")

    # correct_answer - ascending notes (happy sound)
    samples = []
    for freq, duration in [(440, 100), (494, 100), (523, 200)]:
        samples.extend(generate_tone(freq, duration))
    write_wav('correct_answer.wav', samples)

    # incorrect_answer - low buzz
    samples = generate_tone(200, 300)
    write_wav('incorrect_answer.wav', samples)

    # level_complete - uplifting fanfare
    samples = []
    for freq, duration in [(523, 150), (659, 150), (784, 300), (880, 400)]:
        samples.extend(generate_tone(freq, duration))
    write_wav('level_complete.wav', samples)

    # streak_milestone - power-up sound (rising frequency)
    samples = []
    sample_rate = 22050
    for freq in range(300, 800, 50):
        duration_ms = 50
        num_samples = int(sample_rate * duration_ms / 1000)
        amplitude = 32767
        for i in range(num_samples):
            sample = amplitude * math.sin(2 * math.pi * freq * i / sample_rate)
            samples.append(int(sample))
    write_wav('streak_milestone.wav', samples)

    # cosmetic_unlock - magical sparkle (multiple tones)
    samples = []
    for freq, duration in [(587, 80), (659, 80), (784, 80), (659, 80), (784, 160)]:
        samples.extend(generate_tone(freq, duration))
    write_wav('cosmetic_unlock.wav', samples)

    # point_redemption - coin clink sound
    samples = []
    for freq, duration in [(880, 100), (784, 200)]:
        samples.extend(generate_tone(freq, duration))
    write_wav('point_redemption.wav', samples)

    # pop - bubble pop (single sharp note)
    samples = generate_tone(600, 150)
    write_wav('pop.wav', samples)

    print("\nTest audio files generated successfully!")
    print("Note: These are minimal test sounds. Replace with professional audio for production.")
    print("\nTo convert WAV to MP3:")
    print("  ffmpeg -i assets/sounds/correct_answer.wav -q:a 9 assets/sounds/correct_answer.mp3")

if __name__ == '__main__':
    main()
