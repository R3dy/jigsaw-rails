class ContactsWorker
  include Sidekiq::Worker

  def request_new_page(url, cookies)
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

  def perform(company_jigsaw_id, record_id, company_id)
    page = request_new_page("/BC.xhtml?&nextURL=http://www.jigsaw.com/SearchContact.xhtml?companyId=#{company_jigsaw_id}&contactId=#{record_id}", nil)
    record = Hash.new
    record[:jigsawid] = record_id.to_i
    record[:company_id] = company_id
    values = page.body.split('id=')
    values.each do |value|
      case
      when value.include?('firstname')
        record[:firstname] = clean_this_line(value)
      when value.include?('lastname')
        record[:lastname] = clean_this_line(value)
      when value.include?('"title" title="')
        record[:title] = clean_this_line(value)
      when value.include?('city">')
        record[:city] = clean_this_line(value)
      when value.include?('state">')
        record[:state] = clean_this_line(value)
      when value.include?('zip">')
        record[:zip] = clean_this_line(value)
      end	
    end
    createcontact = Contact.new(record)
    createcontact.save
  end

  def clean_this_line(line)
    clean = line.split('">')[1].split('<')[0]
    if clean.include?('&#')
      return clean.split('&#')[0]
    end
    return clean
  end

end
