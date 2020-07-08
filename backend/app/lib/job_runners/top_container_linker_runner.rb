require_relative "../bulk_import/top_container_linker"
require 'json'
class TopContainerLinkerRunner < JobRunner

  register_for_job_type('top_container_linker_job', :hidden => true)

  def run
     
    begin
      job_data = @json.job
     
      DB.open(DB.supports_mvcc?,
              :retry_on_optimistic_locking_fail => true) do

        begin
          RequestContext.open(:current_username => @job.owner.username,
            :repo_id => @job.repo_id) do
            if @job.job_files.empty?
              raise Exception.new("No file to process for top container linkin")
            end
            input_file = @job.job_files[0].full_file_path
            
            current_user = User.find(:username => @job.owner.username)
            @validate_only = @json.job["only_validate"] == "true"
            params = parse_job_params_string(@json.job_params)
            params[:validate] = @validate_only
            params[:resource_id] = @json.job['resource_id']
            params[:repo_id] = @job.repo_id

            @job.write_output("Creating new top container linker...")
            @job.write_output("Repository: " + @job.repo_id.to_s)
            @job.write_output(JSON.pretty_generate(job_data))
            @job.write_output(JSON.pretty_generate(params))
            tcl = TopContainerLinker.new(input_file, @json.job["content_type"], current_user, params)

            begin 
              report = tcl.run
              write_out_errors(report)
              
              self.success!
              
            rescue Exception => e
              report = tcl.report
              write_out_errors(report)
              @job.write_output(e.message)
              @job.write_output(e.backtrace)
              raise Sequel::Rollback
            end
         end
         end
       end
    end
  end
  
  private
  def write_out_errors(report)
    modified_uris = []
    report.rows.each do |row|
      if !row.archival_object_id.nil?
        modified_uris << row.archival_object_id
      end
      #Report out the collected data:
      if !row.errors.empty?
        row.errors.each do |error|
          @job.write_output(error)
        end
      end
      if !row.info.empty?
        row.info.each do |info|
          @job.write_output(info)
        end
      end
    end
    if modified_uris.empty?
      @job.write_output("No records modified.")
    else
      @job.write_output("Logging modified records.")
    end
    @job.record_created_uris(modified_uris.uniq)
  end

end
