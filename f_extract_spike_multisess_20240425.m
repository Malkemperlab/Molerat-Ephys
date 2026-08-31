function f_extract_spike_multisess_20240425(KsDir,rep)
%%% extracting spike times and...
%%% loading files

inputfile_stm = fullfile(KsDir,'ADC_data.mat');

load(inputfile_stm,'Onsets_second','Offset_second','Onsets_ind')
spike_times_ind   = readNPY([KsDir ,'\spike_times.npy']);
spike_cluster = readNPY([KsDir ,'\spike_clusters.npy']);
% unit_locations = readNPY([KsDir ,'\unit_locations.npy']); useles crap!
[cids, cgs]   = readClusterGroupsCSV([KsDir ,'\cluster_group.tsv']); 
% readClusterGroupsCSV does not handle the unrefrenced cluster problem in phy, which means the
% lenght of cgs will shrink and wont be comparable with the one from unit
% locations! unit locations must be computed again or find a way to map cids from SI to  
phy_table = readtable([KsDir ,'\cluster_info.tsv'], "FileType","text",'Delimiter', '\t');
ise = cellfun(@isempty, phy_table.group); phy_table(ise,:)=[]; % remove the unrefrenced clusters!



% sp = loadKSdir(KsDir); %% this loads good, mua and unsorted units
% [spikeAmps, spikeDepths, templateYpos, tempAmps, tempsUnW, tempDur, tempPeakWF] = ...
%     templatePositionsAmplitudes(sp.temps, sp.winv, sp.ycoords, sp.spikeTemplates, sp.tempScalingAmps);

    % - 0 = noise
    % - 1 = mua
    % - 2 = good
    % - 3 = unsorted

    good_cid_ind= cgs==2 |cgs==1 | cgs==3;
    good_cid=cids(good_cid_ind);
    %good_cid=cids;


sess_names = ["fear" ;"grating";"magnetic"];
PST        = [ 1     ; 0.4     ; 0.75     ];         % pre-stimulus time sec
% Get list of files and directories in 'base_folder' and its subdirectories
contents = dir(fullfile(KsDir, '**', '*.mat'));
% Extract file paths
mat_files = {contents(~[contents.isdir]).name};
mat_files = strcat( {contents(~[contents.isdir]).folder}, filesep, mat_files)';
mat_files = mat_files(contains(mat_files, 'log')); % Filter files containing 'log' in their names


% convert and calculate the depth
disp(KsDir)
insertion_len = input('Enter the insertion length of the electrode (micrometers): ');
alpha_deg = input('Enter the lateral-to-medial angle (degrees): ');
beta_deg = input('Enter the anterior-posterior angle (degrees): ');
% alpha_deg = 90 - alpha_deg;
% beta_deg = 90 - beta_deg;
alpha = deg2rad(alpha_deg);
beta = deg2rad(beta_deg);

U_loc_from_tip = phy_table.depth +175; % Location of units in um from the tip of the electrode
% disp(max(U_loc_from_tip))
U_loc_from_surf = insertion_len - U_loc_from_tip;
% Convert unit locations to actual depth
unit_depths = U_loc_from_surf * cos(alpha) * cos(beta);
indd = unit_depths <0;
disp(unit_depths(indd & good_cid_ind'))
if rep
    figure;histogram(unit_depths(good_cid_ind),50)
    xlabel("depth (um)")
    ylabel("# units")
    set(gca,"FontName","Arial","FontSize",14)
    saveas(gcf,[KsDir,'\unit_depth_hist.png'])
    saveas(gcf,[KsDir,'\unit_depth_hist.pdf'])
end



for sess=1:length(Onsets_ind)

    onsets_ind = Onsets_ind{sess};
    onsets_second = Onsets_second{sess};
    offset_second = Offset_second{sess};

    Synch_chan = 5 ;  % here we use synch chan as a robost stimulus onset. later for each stim they should be corrected.

    Stim_onset_ind=onsets_ind{Synch_chan} ;              %starting point of stimulus
    Stim_onset_sec=onsets_second{Synch_chan} ;              %starting time of stimulus
    Stim_offset_sec=offset_second{Synch_chan} ;              %end time of stimulus


    log_file_name = mat_files(contains(mat_files, sess_names(sess))); % Filter files containing session names
    if sess_names(sess)== "magnetic"
        log= load(log_file_name{1});
        trial_schedule =[];
        for i=1:length(log.magnet_locations)*length(log.magnet_mode)
            block_tr = zeros(log.N_trail,1)+i*0.75;
            trial_schedule = vertcat(trial_schedule,block_tr);

        end
        stim_len = mean(Stim_offset_sec(1:100)-Stim_onset_sec(1:100));

    else
        load(log_file_name{1},'trial_schedule');

        %get the length of stimuli
        stim_type = unique(trial_schedule(:,1));
        N_stim_type = length(stim_type);
        stim_len=zeros(1,N_stim_type);
        for i=1:N_stim_type
            trial_idx= trial_schedule(1:50,1)==stim_type(i);
            stim_len(i) = mean(Stim_offset_sec(trial_idx)-Stim_onset_sec(trial_idx));
        end
        % convert trial schedule to 1d trial schedule
        stim_type2_ind   = trial_schedule(:,1)==2;
        trial_schedule (stim_type2_ind,2) = trial_schedule (stim_type2_ind,2) *10;
        stim_type3_ind   = trial_schedule(:,1)==3;
        trial_schedule (stim_type3_ind,2) = trial_schedule (stim_type3_ind,2) *100;
        trial_schedule=trial_schedule(:,2);
    end


    condLabels = unique(trial_schedule);


    % session_number=1;
    session_name=sess_names(sess);

    fs  =30000;                                          %sampling frequency

    Nt= min(length(trial_schedule), length(Stim_onset_ind));
    pst=PST(sess) ;                                             % pre-stimulus time sec
    % dx= 1e-3;                                            % bin size
    % stim_len=mean(stimulus_length{session_number})/fs;
    %     band_test=-pst:pst:stim_len;
    %%%
    trial_onset_ind = floor(Stim_onset_ind-(pst*fs));      %starting point of trials in the data
    % nsample=floor(mean(diff(trial_onset_ind(2:end-1))));                 %number of samples for each trials
    Nsample=floor((stim_len+2*pst)*fs);                 %number of samples for each trials (now a vector)

    %%%



    spikes=cell(1,2);

    trial_per_cond=cell(1,length(good_cid));

    for neuron=1:length(good_cid) %%%loop over clusters, spike time for selected cluster is extracted
        cid= spike_cluster==good_cid(neuron);
        Neuron_spike_times = spike_times_ind(cid);
        Neuron_spike_times = Neuron_spike_times';
        Neuron_spike_times = double(Neuron_spike_times);
        con_Ntrial=zeros(1,length(condLabels));
        % test_vector=[];
        spike=[];
        for cond=1:length(condLabels)%%% loop over all condition for selected neuron
            ind_trGroup= trial_schedule(1:Nt)==condLabels(cond);
            cond_toi=trial_onset_ind(ind_trGroup);
            cond_soi=Stim_onset_ind(ind_trGroup);
            con_Ntrial(cond)=length(cond_toi);
            if condLabels(cond)<10
                nsample = Nsample(1);
            elseif condLabels(cond)>99
                nsample = Nsample(3);
            else
                nsample = Nsample(2);
            end

            for trial_number=1:con_Ntrial(cond)-1 %% loop over all trails in a condition for alignment spike times
                ind_tr= cond_toi(trial_number)<=Neuron_spike_times & Neuron_spike_times<cond_toi(trial_number)+nsample;
                Tri=Neuron_spike_times(ind_tr);
                if ~isempty(Tri)
                    %%% align
                    Tri=(Tri-cond_soi(trial_number))./(fs);
                    spike=[spike;Tri' , ones(length(Tri),1)*trial_number , ones(length(Tri),1)*cond]; %#ok<AGROW>


                end
            end
            %%PSTH calculation should be done at later stage to
            %%integrate the stim delays

        end
        spikes{neuron}=spike;

    end
    %     if strcmp(session_name,'neon')
    %         sr=f_surround_suppression(myKsDir);
    %         spike_data.surround_suppression=sr;
    %     end
    spike_data.spikes          = spikes;
    spike_data.phy_table       = phy_table (good_cid_ind,:);
    spike_data.pst             = pst;
    spike_data.cluster_depths  = unit_depths(good_cid_ind);
    spike_data.cluster_id      = good_cid;
    spike_data.trial_per_cond  = trial_per_cond;
    spike_data.stim_len        = stim_len;
    % spike_data.evoked_cids     = evoked_cids;
    % spike_data.average_latency = average_latency;
    % spike_data.p_evoked_cids   = p_evoked_cids;
    save(strcat(KsDir,'\',session_name,'_spike_data.mat'),'spike_data')

end
end