class CompaniesWorker
  include Sidekiq::Worker

  def perform(id)
    search = "/SearchContact.xhtml?companyId="
    query = "#{search}#{id.to_s}"
    result = request_new_page(query, nil).body
    if result.include?("This Company is locked.")
      puts "this is a bad company #{id}"
      return
    end
    if result == nil
      return
    end
    newcompany = Hash.new
    newcompany[:jigsawid] = id.to_i
    newcompany[:name] = result.to_s.split('<p><span id="pageTitle">')[1].to_s.split('</span></p>')[0].to_s.force_encoding("UTF-8")
    newcompany[:website] = result.to_s.split('<td class="rJust"><label>Website</label></td>')[1].to_s.split('class="newWindow">')[1].to_s.split('</a>')[0].to_s.force_encoding("UTF-8")
    newcompany[:overview] = result.to_s.split('<div id="wikiSection">')[1].to_s.split('</div>')[0].to_s.force_encoding("UTF-8")
    newcompany[:headquarters] = result.to_s.split('<td  class="rJust"><label>Headquarters</label></td>')[1].to_s.split('<td><p>')[1].to_s.split('<br />')[0].to_s + "\r\n" + result.to_s.split('<td  class="rJust"><label>Headquarters</label></td>')[1].to_s.split('<br />')[1].to_s.split('<a href="')[0].to_s.split('&nbsp;')[0].to_s.force_encoding("UTF-8")
    newcompany[:phone] = result.to_s.split('<td  class="rJust"><label>Phone</label></td>')[1].to_s.split('<td>')[1].to_s.split('</td>')[0].to_s.force_encoding("UTF-8")
    newcompany[:industries] = result.to_s.split('<td  class="rJust"><label>Industries</label></td>')[1].to_s.split('<td>')[1].to_s.split('<p>')[1].to_s.split('</p>')[0].to_s.force_encoding("UTF-8")
    newcompany[:employees] = result.to_s.split('<td  class="rJust"><label>Employees</label></td>')[1].to_s.split('<td>')[1].to_s.split('</td>')[0].to_s.force_encoding("UTF-8")
    newcompany[:revenue] = result.to_s.split('<td  class="rJust"><label>Revenue</label></td>')[1].to_s.split('<td>')[1].to_s.split('</td>')[0].to_s.force_encoding("UTF-8")
    newcompany[:ownership] = result.to_s.split('<td  class="rJust"><label>Ownership</label></td>')[1].to_s.split('<td>')[1].to_s.split('</td>')[0].to_s.force_encoding("UTF-8")
    newcompany[:contacts] = result.to_s.split('<h6 id="contactCount" class="marginTop10">')[1].to_s.split(" ")[0].to_s.force_encoding("UTF-8")
    createcompany = Company.new(newcompany)
    if !createcompany.save
      puts "something went wrong :("
    end
  end

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

  def harvestasinglerecord(company_jigsaw_id, record_id, company_id)
    page = request_new_page("/BC.xhtml?&nextURL=http://www.jigsaw.com/SearchContact.xhtml?companyId=#{company_jigsaw_id}&contactId=#{record_id}", nil)
    record = Hash.new
    record[:jigsawid] = record_id.to_i
    record[:company_id] = company_id
    values = page.body.split('id=')
    values.each do |value|
      case
      when value.include?('firstname')
        record[:firstname] = clean_line(value)
      when value.include?('lastname')
        record[:lastname] = clean_line(value)
      when value.include?('"title" title="')
        record[:title] = clean_line(value)
      when value.include?('city">')
        record[:city] = clean_line(value)
      when value.include?('state">')
        record[:state] = clean_line(value)
      when value.include?('zip">')
        record[:zip] = clean_line(value)
      end	
    end
    createcontact = Contact.new(record)
    createcontact.save
  end

end
