% Define the folder containing the saved .mat files
folderPath = 'C:\Users\shirdhankar\Desktop\LFP\';

% Get list of all .mat files in the folder
matFiles = dir(fullfile(folderPath, '*_data.mat'));

% Loop through each .mat file
for k = 1:length(matFiles)
    % Extract the .mat file name
    matFileName = matFiles(k).name;
    fullMatPath = fullfile(folderPath, matFileName);
    
    % Extract base name without "_data.mat"
    baseName = erase(matFileName, '_data.mat');
    
    % Load the .mat file into the workspace
    fprintf('Loading data from: %s\n', matFileName);
    load(fullMatPath);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    Fs=32000;
    Downsampling_frequency = 250;
    
    theta_freq = [3 6];
    delta_freq = [1 3];
    conv_cm = 0.1; % measured dist / real dist
     
    speed_highcut = 100;
    min_speed_corr = 0; % min speed value for speed freq corr
    max_speed_corr =40; % max speed value for speed freq corr
    speed_bin = 1; %cm/sec
    
    %%%%%%%%%%%%%%%%%%%% PATH
    diffposts = diff(PosMtx(:,1));
    posts = [];
    for i =1:length(diffposts)
        posts(i)=sum(diffposts(1:i));
    end
    posts = [0, posts];
    posts = (posts/1000)';
    % posts = posts*1000;
    posx=PosMtx(:,2);
    posy=PosMtx(:,3);
    % then smooth
    [posx,posy] = smooth_path(posx,posy); % only if you need to smooth path
    %%
    EEGvalues_new = EEGvalues;
    EEGvalues_new=EEGvalues_new(:);
    EEGtsnew = 0:1/Fs:(1/Fs)*length(EEGvalues_new);
    EEGtsnew_duration = EEGtsnew(end);
    
    [p,q] = rat(Downsampling_frequency/Fs);
    EEGvaluesnew_v2=resample(EEGvalues_new,p,q);
    EEGtsnew_v2=0:(EEGtsnew_duration/length(EEGvaluesnew_v2)):(EEGtsnew_duration/length(EEGvaluesnew_v2))*length(EEGvaluesnew_v2);
    EEGtsnew_v2=EEGtsnew_v2(1:length(EEGtsnew_v2)-1)';
    
    %% 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%% Data Cleaning
    
    fs = Downsampling_frequency; % Sampling frequency
    
    % % --- Apply Bandpass Filter (1-100 Hz) ---
    % lowCutoff = 1;  
    % highCutoff = 100;
    % [b, a] = butter(4, [lowCutoff highCutoff] / (fs/2), 'bandpass');
    % EEG_filtered = filtfilt(b, a, EEGvaluesnew_v2);
    
    % --- Apply 50Hz Notch Filter ---
    wo = 50 / (fs/2);
    bw = wo / 35;
    [d, c] = iirnotch(wo, bw);
    EEG_filtered = filtfilt(d, c, EEGvaluesnew_v2);
    
    % % --- Apply Wavelet Denoising ---
    EEG_filtered = wdenoise(EEG_filtered, 4); % 4-level wavelet denoising
    
    % --- Remove Trends ---
    EEG_detrended = detrend(EEG_filtered);
    
    % --- Remove Outliers (Motion Artifacts) ---
    EEG_noOutliers = filloutliers(EEG_detrended, 'linear', 'movmedian', 100);
    
    % --- Median Filtering to Reduce Impulse Noise ---
    EEG_medianFiltered = medfilt1(EEG_noOutliers, 5);
    
    % --- Apply a Savitzky-Golay Filter for Smoothing ---
    EEG_smooth = smoothdata(EEG_medianFiltered, 'sgolay', 15);
    
    EEG_final = EEG_smooth;
    
    %%
    
    %%%%%%%%%%%%%%%%% SPEED 
    % calculate speed for each time bin
    diff_X = abs(diff(posx));
    diff_Y = abs(diff(posy));
    diff_T = abs(diff(posts));
    ispeed = sqrt((diff_X.^2 + diff_Y.^2))*conv_cm./diff_T;
    ispeed = ispeed*1000; % transform in cm/sec for our recording setup
    
    
    % Remove jumps greater than 10 cm/sec
    jump_threshold = 50; % Threshold in cm/sec
    for i = 2:length(ispeed)
        if abs(ispeed(i) - ispeed(i-1)) > jump_threshold
            ispeed(i) = ispeed(i-1); % Replace with previous value
        end
    end
    
    % Apply Gaussian smoothing
    sigma = 10; % Standard deviation for smoothing
    smoothed_speed = imgaussfilt(ispeed, sigma);
    
    % Time axis for plotting (midpoints between timestamps)
    time_midpoints = posts(1:end-1) + diff_T / 2;
    
    % Plot original, jump-filtered, and smoothed speed
    figure;
    plot(time_midpoints, ispeed, '--r', 'LineWidth', 1); % Jump-filtered (dashed red)
    hold on;
    plot(time_midpoints, smoothed_speed, '-b', 'LineWidth', 2); % Smoothed (solid blue)
    xlabel('Time (ms)');
    ylabel('Instantaneous Speed (cm/s)');
    title('Instantaneous Speed Across Time (Jump Removal & Smoothing)');
    legend('Jump-Filtered Speed', 'Smoothed Speed');
    grid on;
    
    smooth_speed_final = smoothed_speed;
    
    
    figure;
    spWindow = 1000;
    
    % --- First Row: Speed plot for 0-100 Hz Spectrogram ---
    subplot(4,1,1); % Speed above Spectrogram 1
    plot(time_midpoints, smooth_speed_final, '-k', 'LineWidth', 2); % Smoothed speed in black
    ylabel('Speed (cm/s)');
    title('Animal Speed Across Time');
    grid off;
    xlim([min(posts) max(posts)]);
    ylim([min(smooth_speed_final) max(smooth_speed_final)]);
    %set(gca, 'TickLength', [0.01, 0.02], 'TickDir', 'out');
    set(gca, 'XTickLabel', []); % Remove X-tick labels to align with spectrogram
    
    % --- Second Row: EEG Spectrogram (0-100 Hz) ---
    subplot(4,1,2); % First Spectrogram
    spectrogram(EEG_final, spWindow, [], [], Downsampling_frequency, 'yaxis'); % Compute spectrogram
    ylim([0 100]); clim([20 80]); colormap jet;
    set(gca, 'TickLength', [0.01, 0.02], 'TickDir', 'out');
    title('EEG Spectrogram (0-100 Hz)');
    xlabel('Time (ms)');
    ylabel('Frequency (Hz)');
    
    % Move colorbar to bottom
    cbar = colorbar('SouthOutside'); 
    set(cbar, 'Position', [0.15, 0.45, 0.7, 0.02]); % Adjust position for better fit
    
    % --- Third Row: EEG Spectrogram (0-20 Hz) ---
    subplot(4,1,3); % Second Spectrogram
    spectrogram(EEG_final, spWindow, [], [], Downsampling_frequency, 'yaxis'); % Compute spectrogram
    ylim([0 20]); clim([20 80]); colormap jet;
    set(gca, 'TickLength', [0.01, 0.02], 'TickDir', 'out');
    title('EEG Spectrogram (0-20 Hz)');
    xlabel('Time (ms)');
    ylabel('Frequency (Hz)');
    
    % Colorbar at the bottom
    cbar = colorbar('SouthOutside'); 
    set(cbar, 'Position', [0.15, 0.25, 0.7, 0.02]); 
    
    
    % % --- Second Row: EEG Spectrogram (0-100 Hz) ---
    % subplot(4,1,2); % First Spectrogram
    % spectrogram(EEG_final, spWindow, [], [], Downsampling_frequency, 'yaxis'); % Compute spectrogram
    % ylim([0 100]); clim([20 80]); colormap jet;
    % set(gca, 'TickLength', [0.01, 0.02], 'TickDir', 'out');
    % title('EEG Spectrogram (0-100 Hz)');
    % xlabel('Time (ms)');
    % ylabel('Frequency (Hz)');
    % 
    % % --- Third Row: EEG Spectrogram (0-20 Hz) ---
    % subplot(4,1,3); % Second Spectrogram
    % spectrogram(EEG_final, spWindow, [], [], Downsampling_frequency, 'yaxis'); % Compute spectrogram
    % ylim([0 20]); clim([20 80]); colormap jet;
    % set(gca, 'TickLength', [0.01, 0.02], 'TickDir', 'out');
    % title('EEG Spectrogram (0-20 Hz)');
    % xlabel('Time (ms)');
    % ylabel('Frequency (Hz)');
    
    %%
    %%%%%%%%%%%%%%%%%%%%%%%%%% Saving that data
    
    % Save the current figure as .fig and .jpg
    savefig(gcf, [baseName '.fig']);
    saveas(gcf, [baseName '.jpg']);
    
    % Save the current workspace to the same directory as .mat file
    save([baseName '.mat']);

end

disp('LFP Analysis Completed.');