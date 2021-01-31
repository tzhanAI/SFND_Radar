clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%

range_max = 200;    % radar maximum range in m
res_range = 1;      % range resolution in m
c = 3e8;            % speed of light in m/s


%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant

R = 110;        % init distance of the target
v = -20;        % speed of the target (constant v, in range [-70,70] m/s)


%% FMCW Waveform Generation

% *%TODO* :
% Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.

% sweep time for each chirp is defined as rule by 5.5 times of round trip
% time for maximum range
Tchirp =  5.5 * 2 * range_max / c;
Bandwidth = c / (2 * res_range);        % bandwidth for the each chirp for given resolution
Slope = Bandwidth / Tchirp;             % the slope of the chirp

% Operating carrier frequency of Radar 
fc = 77e9;                  % carrier freq of operation
                                                          
% The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
% for Doppler Estimation. 
Nd = 128;                   % # of doppler cells OR # of sent periods % number of chirps

% The number of samples on each chirp. 
Nr = 1024;                  % for length of time OR # of range cells in FFT

% Timestamp for running the displacement scenario for every sample on each
% chirp (linspace() generate linearly spaced vector)
t = linspace(0, Nd*Tchirp, Nr*Nd); %total time for samples

%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx = zeros(1,length(t));      %transmitted signal
Rx = zeros(1,length(t));      %received signal
Mix = zeros(1,length(t));     %beat signal

%Similar vectors for range_covered and time delay.
r_t = zeros(1,length(t));
td = zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 
for i=1:length(t)         
    % *%TODO* :
    % For each time stamp update the Range of the Target for constant velocity. 
    r_t(i) = R + v * t(i);
    td(i) = 2 * r_t(i) / c;     % time delay or trip time for radar signal
    
    % *%TODO* :
    % For each time sample we need update the transmitted and received signal. 
    Tx(i) = cos(2*pi*(fc*t(i) + (Slope*t(i)^2)/2));
    Rx(i) = cos(2*pi*(fc*(t(i) - td(i)) + (Slope*(t(i) - td(i))^2)/2));
    
    % *%TODO* :
    % Now by mixing the Transmit and Receive generate the beat signal
    % This is done by element wise matrix multiplication of Transmit and
    % Receiver Signal (C = A.*B) This process in turn works as frequency 
    % subtraction.
    
    % beat signal = cos(2pi((2*slope*R/c) * t + (2*fc*v/c)* t))
    % insed the cos() func, the first term gives Range and 2nd gives
    % Doppler, By implementing the 2D FFT on this beat signal, we can
    % extract both Range and Doppler information
    Mix(i) = Tx(i) * Rx(i);      
end


%% RANGE MEASUREMENT

% *%TODO* :
% reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
% Range and Doppler FFT respectively.
Mix = reshape(Mix,[Nr,Nd]);

%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize. The result is a matrix of range(m) verses # of chirp
Y = fft(Mix, Nr);       % size = Nr x Nd, 1024 x 128;
Y = Y/Nr;

% The output of FFT of a signal is a complex number (a+jb).
% Since we just care about the magnitude we take the absolute value
% (sqrt(a^2+b^2)) of the complex number.
P2 = abs(Y);

% FFT output generates a mirror image of the signal. But we are only
% interested in the positive half of signal length L, since it is the 
% replica of negative half.
% Compute the single-sided spectrum P1 based on P2 and the even-valued
% signal length Nr.
P1 = P2(1:Nr/2);

%plotting the range
figure ('Name','Range from First FFT')
subplot(2,1,1)

% *%TODO* :
% plot FFT output 
plot(P1);
axis ([0 200 0 1]);



%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM

% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);             % sig_fft2 size: 1024 x 128

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);       % sig_fft2 size: 512 x 128
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);


%% CFAR implementation
%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
Tr = 10;
Td = 8;

%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
Gr = 4;
Gd = 4;

% offset the threshold by SNR value in dB
offset = 8;

%Create a matrix to store noise_level(in db) for each iteration on training cells
noise_level = -ones(Nr/2,Nd);

% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


% Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
% CFAR
signal_CFAR = RDM;
max_T = 1;
% slide the window, CUT needs to have margin, (i,j) is the center
for i = Tr+Gr+1:Nr/2-(Gr+Tr)
    for j = Td+Gd+1:Nd-(Gd+Td)
        % iter over every cell in the window, except guard cells and CUT
        noise = 0;
        for p = i-(Tr+Gr):i+Tr+Gr
            for q = j-(Td+Gd):j+Td+Gd
                if (abs(i-p) > Gr || abs(j-q) > Gd)
                    noise = noise + db2pow(RDM(p,q));
                end
            end
        end
        % calculate the average of noises in trianing cells
        noise = noise / (2*(Tr+Gr+1)*2*(Td+Gd+1) - (Gr*Gd) - 1);
        threshold = pow2db(noise);
        noise_level(i,j) = threshold;
        % add SNR offset to the thrshold
        threshold = threshold + offset;     % in db
        % compare 2D FFT result in (i,j) with its threshold
        CUT = RDM(i,j);
        if CUT > threshold
            signal_CFAR(i,j) = max_T;
        else
            signal_CFAR(i,j) = 0;
        end
    end
end

% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 
for i = 1:Nr/2
    for j = 1:Nd
        if (i < Tr+Gr+1 || i > Nr/2-(Tr+Gr) || j < Td+Gd+1 || j > Nd-(Td+Gd))
            signal_CFAR(i,j) = 0;
        end
    end
end

% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
figure,surf(doppler_axis,range_axis, signal_CFAR);
colorbar;



 
 