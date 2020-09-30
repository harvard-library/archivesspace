
# frozen_string_literal: true

class ArchivesSpaceService < Sinatra::Base
  # Supports top container linking via spreadsheet
  Endpoint.post('/bulkimport/linktopcontainers')
          .description('Top Container linking from a Spreadsheet')
          .params(['repo_id', :repo_id],
                  ['rid', :id],
                  ['filename', String, 'the original file name'],
                  ['filepath', String, 'the spreadsheet temp path'],
                  ['filetype', String, 'file content type']
                )
          .permissions([:update_resource_record])
          .returns([200, 'HTML'],
                   [400, :error]) do
    #Validate spreadsheet
    filepath = params.fetch(:filepath)
    filetype = params.fetch(:filetype)
    rid = params.fetch(:rid)
    tclValidator = TopContainerLinkerValidator.new(filepath, filetype, current_user, params)
    report = tclValidator.run
    errors = [] 
    unless report.terminal_error.nil?
      errors << report.terminal_error
    end
    #All errors are terminal for validation
    report.rows.each do |error_row|
      if (!error_row.errors.empty?)
        errors << error_row.errors.join(", ")
      end
    end
    #If it fails, return the template
    if (!errors.empty?)
      erb :'bulk/top_container_linker_response', locals: {report: report}
    else
      #Otherwise send an error so it triggers a job creation
      raise BulkImportException.new()
    end
  end
  
  # Supports top container linking via spreadsheet
  Endpoint.post('/bulkimport/linktopcontainers')
          .description('Top Container linking from a Spreadsheet')
          .params(['repo_id', :repo_id],
                  ['rid', :id],
                  ['filename', String, 'the original file name'],
                  ['filepath', String, 'the spreadsheet temp path'],
                  ['filetype', String, 'file content type']
                )
          .permissions([:update_resource_record])
          .returns([200, 'HTML'],
                   [400, :error]) do
    #Validate spreadsheet
    filepath = params.fetch(:filepath)
    filetype = params.fetch(:filetype)
    rid = params.fetch(:rid)
    tclValidator = TopContainerLinkerValidator.new(filepath, filetype, current_user, params)
    report = tclValidator.run
    errors = [] 
    unless report.terminal_error.nil?
      errors << report.terminal_error
    end
    #All errors are terminal for validation
    report.rows.each do |error_row|
      if (!error_row.errors.empty?)
        errors << error_row.errors.join(", ")
      end
    end
    #If it fails, return the template
    if (!errors.empty?)
      erb :'bulk/top_container_linker_response', locals: {report: report}
    else
      #Otherwise send an error so it triggers a job creation
      raise BulkImportException.new()
    end
  end
end
