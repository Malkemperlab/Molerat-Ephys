
function [adc_onset_seconds,adc_offset_seconds,adc_onset_idx] = ...
    f_get_onsets_20240425(raw_data, min_ISI_secs, report, invert_signal,ADC_threshold,end_of_session)



if invert_signal
    raw_data = -raw_data;
end
%keyboard

% ADC_threshold = 0.3; %0.4 %1000
ADC_sampling_freq = 30000;

normalized_photodiode_data = raw_data - min(raw_data);
normalized_photodiode_data = normalized_photodiode_data ./ max(normalized_photodiode_data);
%keyboard
adc_above_thres_idx = find(normalized_photodiode_data > ADC_threshold);
% adc_above_thres_idx = [-1 adc_above_thres_idx];
adc_above_thres_interval = diff(adc_above_thres_idx);

% keyboard
idx = find(adc_above_thres_interval > min_ISI_secs * ADC_sampling_freq); %this finds the offset

% idx_miss =find(adc_above_thres_interval > 3 * min_ISI_secs * ADC_sampling_freq);
% trial_miss=find(ismember(idx,idx_miss));
% trial_miss=trial_miss(2:end);
% trial_miss=trial_miss+linspace(0,length(trial_miss)-1,length(trial_miss));
    % Sts=ind(locs+1);Sts=Sts';    %starting time of stimulus
    % Sts=[ind(1),Sts]; %#ok<AGROW>
idx2 = idx + 1; %otherwise you get the offset
adc_onset_idx = adc_above_thres_idx(idx2);
if ~isempty(adc_above_thres_idx);adc_onset_idx = [ adc_above_thres_idx(1), adc_onset_idx];end
adc_onset_seconds = adc_onset_idx/ADC_sampling_freq;
adc_offset_seconds = adc_above_thres_idx(idx)/ADC_sampling_freq;

if ~isempty(adc_offset_seconds)
    % add ard value to the last offset as it is missed
    adc_offset_seconds = [adc_offset_seconds, adc_onset_seconds(end)+adc_offset_seconds(1)-adc_onset_seconds(1)];

    if adc_offset_seconds(1)<0
        adc_offset_seconds(1)=[];
    end
end

fals_tr_ind = adc_offset_seconds-adc_onset_seconds < 0.4; % to find short trials! which are false 
adc_onset_seconds(fals_tr_ind) = [];
adc_offset_seconds(fals_tr_ind)= [];
adc_onset_idx(fals_tr_ind) = [];
if report == 1
    figure('name', 'ISIs')
    subplot(3,1,1)
    plot(adc_above_thres_interval, 'x')
    subplot(3,1,2)
    hist(adc_above_thres_interval,50)

    subplot(3,1,3)
    plot((1:length(normalized_photodiode_data))/ADC_sampling_freq, normalized_photodiode_data, '.-')
    hold all
    plot(adc_onset_seconds, zeros(1,length(adc_onset_idx)), 'gx')
    plot(adc_offset_seconds, zeros(1,length(adc_offset_seconds)), 'rx')
elseif report == 2
    peek_secs = 10;
    figure('name', sprintf('onsets, first %d seconds', peek_secs))
    subplot(3,1,1)
    plot(adc_above_thres_interval, 'x')
    subplot(3,1,2)
    hist(adc_above_thres_interval,50)

    subplot(3,1,3)

    refline(0,ADC_threshold);

    plot((1:length(normalized_photodiode_data(1:ADC_sampling_freq*peek_secs)))...
        /ADC_sampling_freq, normalized_photodiode_data(1:ADC_sampling_freq*peek_secs), '.-')
    hold all
    plot(adc_onset_seconds(adc_onset_seconds<peek_secs), zeros(1,sum(adc_onset_seconds<peek_secs)), 'gx')
    plot(adc_offset_seconds(adc_offset_seconds<peek_secs), zeros(1,sum(adc_offset_seconds<peek_secs)), 'rx')
    %    % keyboard
end

%   num_trials = length(pd_onset_seconds);
fprintf('found %d onsets\n', length(adc_onset_seconds));
%% add sessions
adc_onset_idx = adc_onset_idx+end_of_session;
adc_onset_seconds = adc_onset_seconds+end_of_session/ADC_sampling_freq;
adc_offset_seconds = adc_offset_seconds +end_of_session/ADC_sampling_freq;

%% TODO add open ephys adc