clear

KsDir = 'D:\ephys\R002\2024-03-12\ks4phy_autocurated';
sess_names = ["fear" ;"grating"];
pd_delay = 128.1313/1000;
% Get list of files and directories in 'base_folder' and its subdirectories
contents = dir(fullfile(KsDir, '**', '*.mat'));
% Extract file paths
mat_files = {contents(~[contents.isdir]).name};
mat_files = strcat( {contents(~[contents.isdir]).folder}, filesep, mat_files)';


log_file_names = mat_files(contains(mat_files, 'log')); % Filter files containing session names


sess=2;

session_name=sess_names(sess);

outputDir           = fullfile(KsDir,session_name);
if ~exist(outputDir, 'dir')
    mkdir(outputDir)
end


load(strcat(KsDir,'\',session_name,'_spike_data.mat'))

log_file_name = log_file_names(contains(log_file_names, sess_names(sess))); % Filter files containing session names
experiment_log =   load(log_file_name{1});
% smoothed_pdf=spike_data.smoothed_pdf{neuron};
stim_len=spike_data.stim_len;

for neuron=1:length(spike_data.spikes)
    % xp=spike_data.xp;
    spike_in_neuron=spike_data.spikes{neuron};
    Ntrial_per_cond=spike_data.trial_per_cond{neuron};
    %id=spike_data.evoked_cids{neuron};
    % Ntrial_per_cond=trial_per_cond{neuron};
    % spike_in_neuron= spikes{neuron};
    % smoothed_pdf=smoothed_pdfs{neuron};
    %% plot options

    Nrow=4; Ncol=4;

    pst= spike_data.pst;
    if ~isempty(spike_in_neuron)
        spike_in_neuron(:,1)= spike_in_neuron(:,1)-pd_delay;
        
        figure('units','normalized','outerposition',[0 0 0.8 0.8],'Visible','off');
        for ang = 1:length(experiment_log.grating_angles_in_degrees)





            grating_spike=spike_in_neuron(spike_in_neuron(:,3)==ang,1:2);
            

            if ang<=4
                subplot(Nrow,Ncol,ang)
            else
                subplot(Nrow,Ncol,ang+4)
            end


            scatter(grating_spike(:,1),grating_spike(:,2),4,'black','fill')
            % if ~isempty(grating_spike);xlim([min(grating_spike(:,1)), max(grating_spike(:,1))]);end
            xlim([-pst-pd_delay,stim_len(1)+pst-pd_delay]); ylim([0 50]) ; ylabel('trial'); xticklabels([])
            title(['angle:',num2str(experiment_log.grating_angles_in_degrees(ang))]); ax = gca; ax.FontSize = 10;
            xline([0, stim_len(1)],'-r','LineWidth',1.2)



            if ang<=4
                subplot(Nrow,Ncol,ang+4)
            else
                subplot(Nrow,Ncol,ang+8)
            end


            histo= histogram(grating_spike(:,1),'BinWidth',10^-2);
            histov= smoothdata(histo.Values,'gaussian',5);
            plot(histo.BinEdges(2:end)-10^-2,histov,'LineWidth',1.5)
            % if ~isempty(grating_spike);xlim([min(grating_spike(:,1)), max(grating_spike(:,1))]);end
            xlim([-pst-pd_delay,stim_len(1)+pst-pd_delay]);
            ylabel('spike/sec'); xlabel('time (sec)')
            ax = gca; ax.FontSize = 10; box off
            xline([0, stim_len(1)],'-r',{'onset','offset'},'LineWidth',1.2)
        end


        saveas(gcf,strcat(outputDir,'\raster_PSTH_cluster-',num2str(neuron),'.png'))
        print(gcf, strcat(outputDir,'\raster_PSTH_cluster-',num2str(neuron),'.pdf'), '-dpdf', '-bestfit');
        close gcf
    end
end



