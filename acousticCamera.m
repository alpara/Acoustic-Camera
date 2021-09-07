% @title        Acoustic Camera
% @file         acousticCamera.m
% @short        a delay and sum algorithm for the acoustic image extraction
% @version      0.1
% @date         06. September 2021
% @copyright    All rights reserved by Christoph Lauer
% @author       Christoph Lauer
% @contributors persons
% @client       company
% @language     MATLAB (Octave)
% @packages     Image Processing Toolbox, Parallel Computing Toolbox...
% @param        none
% @return       none
% @notes        note
% @todo         finished so far
% @copyright    Christoph Lauer
% @license      cle commerial license
% @brief        This matlab file implements an Delay and Sum algorithm and generates images and a video


%% 0.) CONSTANTS
% NOTE: some constants are defined while read the metadata
clear;
temperature   = 20.0;                    % in °C
speedOfSound = (331.5 + 0.6*temperature);
projectionPlaneDistance = 3;             % Z in meter
projectionPaneWidth     = 4;             % X in meter
projectionPaneHeight    = 4;             % Y in meter
projectionPaneDelta     = 0.1;           % Δ in meter (influences the image size)
samplesPerImage         = 1000;          % in samples (aka window size)


%% 1.) RAW DATA
% parse the microphone array raw data
% 1.1) open the array metadata JSON file and extract the microphone array recording metadata
fid = fopen('data/MicrophoneArrayData.json');
str = char(fread(fid,inf)');
fclose(fid);
metaData = jsondecode(str);
sampleRate = metaData.samplerate;                      % CONSTANT the sample rate in 1/s
numChannels = metaData.lengthInSeconds;                % CONSTANT the signal duration in meter
numChannels = length(metaData.elements);               % CONSTANT the number of microphones
% 1.2) open the RAW audio data
fid = fopen('data/MicrophoneArrayData.raw','rb');
data=fread(fid,[numChannels sampleRate*numChannels],'int16');
fclose (fid);
% 1.3) build the microphone array struct
for m = 1:numChannels
    mic(m).x = metaData.elements(m).x;
    mic(m).y = metaData.elements(m).y;
    mic(m).z = metaData.elements(m).z;
    mic(m).samples = data(m,:);
end
numSamples = length(mic(1).samples);                    % CONSTANT the total number of samples in each channel
audiowrite("data/sample.wav",data(100,:)/10000.0,sampleRate) % save one test channel


%% 2.) PLOT ARRAY
% 2.1) plot the geometry of the microphone array
for m = 1:numChannels
    plotX(m) = mic(m).x;
    plotY(m) = mic(m).y;
end
scatter(plotX, plotY)
title('Microphone Array Geometry (in meter)')
% 2.1) calculate the computation times for the APPLE M1 computer
timeImage = numSamples * projectionPaneWidth/projectionPaneDelta * projectionPaneHeight/projectionPaneDelta / 3e6;
s = seconds(timeImage); s.Format = 'hh:mm:ss';
fprintf("Estimated Computation Duration for ONE image :" + char(s) + " (hh:mm:ss)\n");
timeVideo = numSamples / samplesPerImage * timeImage;
s = seconds(timeVideo); s.Format = 'hh:mm:ss';
fprintf("Estimated Computation Duration for ALL images:" + char(s) + " (hh:mm:ss)\n");


%% 3.) VIRTUAL PROJECTION PLANE - raytracing the virtual projection plane
imageDimX = projectionPaneWidth  / projectionPaneDelta+1; % image width
imageDimY = projectionPaneHeight / projectionPaneDelta+1; % image height
disp("Image Dimension: " + imageDimX + "x" + imageDimY);
numImages = floor(numSamples / samplesPerImage)-1; % number of image

%% 3.1) PARRALELIZATION LOOP - windowing over the images
parfor image = 1:numImages                                                             % loop over the images=windows (***PARRALELIZED START***)
    sampleOffset = image * samplesPerImage; % window begin in samples
    yImage = 0;  % counts over the width of the image
    xImage = 0;  % counts over the height of the image
    fprintf("Image " + image + ":");
    IMAGE = zeros (imageDimX, imageDimY); % pre allocate the image array
    for y = -projectionPaneHeight/2:projectionPaneDelta:projectionPaneHeight/2         % loop over the image height
        yImage = yImage + 1; % increase image width counter
        for x = -projectionPaneWidth/2:projectionPaneDelta:projectionPaneWidth/2       % loop over the image width
            xImage = xImage + 1; % increase image height counter
            distanceSamples = zeros(1,numChannels); % pre-allocate
            %% 3.2) DELAY (extract the distances)
            for m = 1:numChannels                                                       % loop over the microphone channels to extarct the delay
                distanceVector = [mic(m).x ,mic(m).y ,0; x ,y ,projectionPlaneDistance];
                distanceMeter = pdist(distanceVector,'euclidean'); % distance from microphone m to the image point in the virtual projection plane
                distanceSamples(m) = distanceMeter / speedOfSound * sampleRate; % distance in samples
            end %channels
            distanceSamples = distanceSamples - min(distanceSamples);
            %% 3.3) SUM (beam one the image point)
            for sample = sampleOffset:sampleOffset+samplesPerImage                      % loop over the samples to sum
                sum = 0;
                for m = 1:numChannels                                                   % loop over the channels for each sample
                    indexWithDelay = round(sample + distanceSamples(m)); % the shifted index of the saample array for microphone m
                    sum = sum + mic(m).samples(indexWithDelay); % sum of the image point in the projection pane
                end %channels
                IMAGE(xImage,yImage) = IMAGE(xImage,yImage) + abs(sum);
            end %samples
        end %width
        xImage = 0; % new image point
        fprintf('.'); if (mod(yImage,10) == 0) fprintf("%i",yImage); end
    end %height
    %% 3.4) SAVE THE IMAGE
    yImage = 0; % new image row
    fprintf('\n');
    IMAGE = IMAGE - min(IMAGE(:));            % normalize
    IMAGE = IMAGE ./ max(IMAGE(:)) .* 256;
    filename = [sprintf('img%03d',image) '.png'];
    imwrite(IMAGE, jet(256), ['images/',filename]);
end %images/offset/windows                                                                                       (***PARRALELIZED END***)


%% 4.) GENERATE THE MOVIE
% 4.1) oarse the video folder for files
disp("Generate the Movie...");
imageNames = dir(fullfile('images','*.png'));
imageNames = {imageNames.name}';
% 4.2) open the video file
outputVideo = VideoWriter(fullfile('images','AcousticCamera.mp4'),'MPEG-4');
outputVideo.FrameRate = 10;
outputVideo.Quality = 95;
open(outputVideo)
colorMap = jet(256);
% 4.3) save the images to the video file
for ii = 1:length(imageNames) %% loop over the images
    img = imread(fullfile('images',imageNames{ii}));
    writeVideo(outputVideo,im2frame(img,colorMap))
end
close(outputVideo)
% 4.4) open the video file
implay("images/AcousticCamera.mp4");           % matlab video player
system("open images/AcousticCamera.mp4");      % macos video player

%% 5.) CLEAN UP
%delete('images/*.png')