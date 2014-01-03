module Jigsawhttp
  ## Copyright (C) 2013 Royce Davis (@r3dy__)
  ### #
  ### #This program is free software: you can redistribute it and/or modify
  ### #it under the terms of the GNU General Public License as published by
  ### #the Free Software Foundation, either version 3 of the License, or
  ### #any later version.
  ### #
  ### #This program is distributed in the hope that it will be useful,
  ### #but WITHOUT ANY WARRANTY; without even the implied warranty of
  ### #MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  ### #GNU General Public License for more details.
  ### #
  ### #You should have received a copy of the GNU General Public License
  ### #along with this program. If not, see <http://www.gnu.org/licenses/>

  # Requests a URL on www.jigsaw.com
  # @param page [String] A page on Jigaws website.  ex. /login.xhtml
  # @return [String] Containing an HTML page
  def request_page(url, cookies)
    headers = {
      "Host" => 'www.jigsaw.com',
      "User-Agent" => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0',
      "Accept" => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      "Accept-Language" => 'en-US,en;g=0.5',
      #"Accept-Encoding" => 'gzip, deflate',
      "Content-Type" => 'text/plain',
      "Pragma" => 'no-cache',
      "Content-Length" => '0',
      "Cache-Control" => 'no-cache',
      "Connection" => 'keep-alive',
      "DNT" => '1',
      "Cookie" => cookies.to_s
    }
    http = Net::HTTP.new('www.jigsaw.com')
    resp, data = http.get(url, headers)
    return resp
  end

  # Simple method to return the output form an HTTP request
  # This is used during DEBUG mode
  def output_http(hash, type, url=nil)
    output = "#{type.upcase}\r\n--------\r\n"
    output << url + "\r\n" if url
    hash.each do |key_pair|
      output << key_pair[0].to_s + ": " + key_pair[1].to_s + "\r\n"
    end
    output << "--------\r\n\r\n"
    return output
  end

  # Extracts the Record ID numbers from a page
  # @param page [String] An HTML web page 
  # @return [Array] containing ID numbers
  def harvest_record_ids(page)
    hrefs = page.body.split('<a href=javascript:showContact(\'')
    record_ids = []
    hrefs.each do |href|
      if href.include?('...,')
        id = href.split('\')')[0]
        unless id.length > 10
          record_ids << id
        end
      end
    end
    return record_ids
  end


  # Extracts the number of records a company has
  # @param page [String] A page object returned from request_page
  # @return [Int] Number of company records
  def harvest_number_of_records(page)
    records = ""
    page.body.each_line do |line|
      if line.include?('var allContactsCount')
        records = line.split('= ')[1].gsub(/;/, '')
      end
    end
    return records.to_i
  end


  # Extracts contact information from a single record
  # @param id [Int] A valid Jigsaw record id
  # @return [Hash] Containing Record fname, lname, title, city, state

  def harvest_single_record(company_id, record_id, cookies, keyword=nil)
    page = request_page("/BC.xhtml?&nextURL=http://www.jigsaw.com/SearchContact.xhtml?companyId=#{company_id}&contactId=#{record_id}", cookies)
    record = {
      "firstname" => '',
      "lastname" => '',
      "title" => '',
      "company" => '',
      "city" => '',
      "state" => '',
      "ID" => ''
    }
    record["ID"] = record_id
    values = page.body.split('id=')
    values.each do |value|
      case
      when value.include?('firstname')
        record["firstname"] = clean_line(value)
      when value.include?('lastname')
        record["lastname"] = clean_line(value)
      when value.include?('"title" title="')
        record["title"] = clean_line(value)
      when value.include?('city">')
        record["city"] = clean_line(value)
      when value.include?('state">')
        record["state"] = clean_line(value)
      when value.include?('_company.xhtml">')
        record["company"] = value.split('company.xhtml">')[1].split('<')[0].to_s
      end	
    end
    case keyword
    when nil
      return record
    else
      return record if record["title"].downcase.include? keyword.downcase
    end
  end

  # Tiny method used by harvest_single_record
  def clean_line(line)
    clean = line.split('">')[1].split('<')[0]
    if clean.include?('&#')
      return clean.split('&#')[0]
    end
    return clean
  end


  # Performs a search query against FreeTextSearch.xhtml
  # @param search [String] Search query in string format
  # @return id [Int] when search returns a single company
  # @return parse_multiple_search_results [Hash] when search returns multiple results
  # @return nil otherwise
  def search_for_company(search, cookies)
    companies = []
    search = search.gsub(/ /, '+')
    searchpage = "/FreeTextSearch.xhtml?opCode=search&autoSuggested=true&freeText="
    result = request_page("#{searchpage}#{search}", cookies)
    if result.body.include?('Contacts at this Company')
      id = result.body.split('id="companyGuid" name="companyGuid" value="')[1].split('"')[0].to_i
    elsif result.body.include?("Contacts Search Results")
      return parse_multiple_search_results_employee(result)
    elsif result.body.include?("did not match any results")
      return nil
    elsif result['Location']
      id = result['Location'].split('/')[5].to_i
    else
      return parse_multiple_search_results(result)
    end
    return id
  end

  def parse_multiple_search_results_employee(page)
    people = ""
    rows = page.body.split('<tr class=\'alt')
    rows.shift
    rows.each do |row|
      people << row.split('id=\'')[1].split('\'')[0].split('_')[1] + "-"
    end
    return people
  end

  # Generates a Hash containing individual companies
  # Used by search_for_company when search returns more then
  # one record
  # @param page [String] An HTML page as a string object
  # @return companies [Hash] Hash containing Company Name, ID & Records
  def parse_multiple_search_results(page)
    companies = []
    rows = page.body.split('<tr class=\'alt')
    rows.shift
    rows.each do |row|
      company = {
        "name" => '',
        "id" => '',
        "records" => ''
      }
      company["name"] = row.split('<a class=\'nowrap\' title=\'')[1].split('\' href=')[0]
      company["id"] = row.split('\' href=\'/id')[1].split('/')[0].to_i
      company["records"] = row.split('=showCompDir&\'>')[1].split('</a>')[0]
      companies << company
    end
    return companies
  end


  # This simply computes the number of records stored in 'numrec' devided evenly by 50
  # Example if numrec == 60 this method will return 2 because we will need to make 2 page requests.  The first showing
  # records 1-50 and the second showing 51-60.
  # @parm numrec [Integer] number of records from a jigsaw query
  def get_number_of_pages(numrec)
    return ((numrec + 50) / 50 * 50) / 50
  end

  # Simple class for dealing with some precentage reporting
  class Numeric

    def self.percent_of(n1,n2)
      n1.to_f / n2.to_f * 100.0
    end

    def self.clean_up_percentage(percent)
      output = percent.to_s.rjust(5, ' ')
      if output.split(".")[0].length > 2
        output = output[1..-1] + "0"
      end
      return output
    end

  end
end
