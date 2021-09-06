# Acoustic-Camera
A Matlab implementation of an Delay-Sum Acoustic Camera Beamformer trough Raytracing.

## Description

The Delay and Sum beamfomer implememnted with Matlab uses a virtual Projection Plane in front of the camera. The Sample Data uses a 3 second white noise signal recorded with an 128 cannel microphone array. The Dimension and Distance of the Virtual Projection Plane can be adjusted in the constances section of the matlab script.

<img src="img0.gif" width="400" height="400" />

The concept of the virtual projection plane.

![alt text](img1.gif)

The microphone array geometry.

![alt text](img2.png)

Rendering time for one 800x800 image is approx 10h on Apple M1 (no parallalization)

![alt text](img3.png)

## Thanks
Thanks to [Jørgen Grythe](https://github.com/jorgengrythe/beamforming) for his RAW data for microphone array.
