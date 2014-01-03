require 'net/http'

class DriverController < ApplicationController
  include Breakbot
  include Jigsawhttp
  include Record

  def index
    render('index')
    break_bot_challenge()
    get_contacts
  end

  def get_contacts
    Company.where('contacts > ?', 1).each { |company| download_company_contacts(company.id) }
  end

  def get_companies
    newprocess = fork do
      (1..5399998).each do |id|
        CompaniesWorker.perform_async(id)
      end
    end
    Process.detach(newprocess)
  end

  def download_company_contacts(company_id)
    company = Company.find(company_id)
    company_record_ids = []
    #Requesting the number of records for your search
    record_count = harvest_number_of_records(request_page("/SearchContact.xhtml?companyId=#{company.jigsawid.to_s}&opCode=showCompDir", nil))
    page_count = get_number_of_pages(record_count)
    #Extracting #{record_count + 1} records from #{page_count} pages
    page_count.times do |num|
      page = num + 1
      #puts "Harvesting Record Numbers From Page: #{page}
      company_record_ids << harvest_record_ids(request_page("/SearchContact.xhtml?companyId=#{company.jigsawid.to_s}&opCode=paging&rpage=#{page}&rowsPerPage=50", nil))
    end
    #Downloading information from #{record_count + 1} individual records.  This may take a while
    company_record_ids.each do |page|
      page.each do |id|
        ContactsWorker.perform_async(company.jigsawid, id, company.id)
      end
    end
  end

end
