require 'spec_helper'

describe 'Search controller' do

  it "has a search user that can view suppressed records" do
    accession = create(:json_accession)
    accession.suppress

    create_nobody_user

    as_test_user("nobody") do
      expect {
        JSONModel(:accession).find(accession.id)
      }.to raise_error(RecordNotFound)
    end

    as_test_user(User.SEARCH_USERNAME) do
      expect(JSONModel(:accession).find(accession.id)).not_to be_nil
    end
  end


  it "doesn't let the search user update records" do
    accession = create(:json_accession)

    as_test_user(User.SEARCH_USERNAME) do
      expect {
        accession.save
      }.to raise_error(AccessDeniedException)
    end

  end


  describe "Endpoints" do

    it "responds to GET requests" do
      get '/search'
      expect(last_response.status).not_to eq(404)
    end

    it "responds to POST requests" do
      post '/search'
      expect(last_response.status).not_to eq(404)
    end

  end

  describe "correctly indexes and searches subcontainers" do

    it "verifies that grandchild container indicator appears in search" do
      # Save top container to the database
      # TODO: how to impersonate admin user to create records in the database?
      top_container = create(:json_top_container)

      as_test_user("admin") do
        top_container = create(:json_top_container)
      end

      # Question: Will this be handled by the periodic indexer?
      instances = [{ instance_type: 'box',
        sub_container:
          {
            :top_container => { ref: top_container.uri },
            :type_2 => "folder",
            :indicator_2 => "a-test-indicator",
            :type_3 => "folder",
            :indicator_3 => "cattywampus", # unique string to test search
          }
        }
      ]

      # Save resource to the database
      as_test_user("admin") do
        resource = create(:resource,
                          instances: instances,
                        )
      end

    #run_index_round

  end
end

