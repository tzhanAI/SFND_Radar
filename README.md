# SFND_Radar
Udacity SFND project 3 Radar object generation and detection

## A.2D Fast Fourier Transform (FFT)
Use 2D FFT to generate range Doppler map (RDM). The y axis has the range of the target.The x axis has the doppler velocity with the zero velocity in the center. The objects appeared on the negative Doppler are approaching targets and the ones on the positive Doppler are the receding targets.
![alt text](https://github.com/tzhanAI/SFND_Radar/blob/main/media/2DFFT.png)

## B.Constant False Alarm Rate (CFAR)
Dynamically selecting threshold to remove clutter using a sliding window across RDM.
![alt text](https://github.com/tzhanAI/SFND_Radar/blob/main/media/CFAR.png)
