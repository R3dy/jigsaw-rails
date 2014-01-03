module Breakbot
  ## Copyright (C) 2013 Royce Davis (@r3dy__)
  ## #
  ## #This program is free software: you can redistribute it and/or modify
  ## #it under the terms of the GNU General Public License as published by
  ## #the Free Software Foundation, either version 3 of the License, or
  ## #any later version.
  ## #
  ## #This program is distributed in the hope that it will be useful,
  ## #but WITHOUT ANY WARRANTY; without even the implied warranty of
  ## #MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  ## #GNU General Public License for more details.
  ## #
  ## #You should have received a copy of the GNU General Public License
  ## #along with this program. If not, see <http://www.gnu.org/licenses/>

  # Checks for the presence of proxy_host and proxy_port options
  # @return both values if set
  def check_proxy()
    if @options[:proxy_host] && @options[:proxy_port]
      return @options[:proxy_host], @options[:proxy_port]
    end
    return nil, nil
  end

  # This sends the very first request to recieve the bot challenge and chellenge-id
  # @param url [STRING] The url to make the HTTP request
  # @return resp.body [STRING] An HTML body object containing challenge and challenge-id
  def make_first_request(url)
    headers = {
      'Host' => 'www.jigsaw.com',
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' => 'en-US,en;q=0.5',
      'Accept-Encoding' => 'gzip, deflate',
      'DNT' => '1',
      'Connection' => 'keep-alive'
    }
    http = Net::HTTP.new('www.jigsaw.com', 80)
    resp, body = http.get(url, headers)
    return resp.body
  end

  # As name suggests.  The second HTTP request which sends the POST challenge, challenge-id and challenge-result
  # If all goes well this method will return the BotMittigation Golden ticket
  # @param url [STRING] The url to make the HTTP request
  # @param challenge_hash [HASH] Hash containing challenge, challenge-id, and challenge-result values
  # @return resp [OBJECT] returns the full response object from the HTTP request 
  def make_second_request(url, challenge_hash)
    headers = {
      'Host' => 'www.jigsaw.com',
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' => 'en-US,en;q=0.5',
      'Accept-Encoding' => 'gzip, deflate',
      'DNT' => '1',
      'X-AA-Challenge-ID' => challenge_hash['ChallengeId'],
      'X-AA-Challenge-Result' => challenge_hash['ChallengeResult'],
      'X-AA-Challenge' => challenge_hash['Challenge'],
      'Content-Type' => 'text/plain',
      'Connection' => 'keep-alive',
      'Pragma' => 'no-cache',
      'Cache-Control' => 'no-cache',
      'Content-Length' => '0'
    }
    http = Net::HTTP.new('www.jigsaw.com', 80)
    resp, body = http.post(url, "", headers)
    return resp
  end

  # This acts as the maind driving method of the library
  # It calls first * second request methods, and also parses the output
  # Ultimatley the purpose of this method is to apply the Golden ticket to the 
  # @cookies instance var.  If that doesn't work there is no point in continuing with 
  # the program
  def break_bot_challenge(id=nil)
    begin
      if id == nil
        id = 12345
      end
      puts "Defeating the evil Bot Detection Challenge, MUAHAHAHA"
      if challenge_hash = parse_challenge_request(make_first_request("/SearchContact.xhtml?companyId=#{id}&opCode=showCompDir"))
        puts "Result for Challenge -" + challenge_hash['Challenge'].to_s + " = " + challenge_hash['ChallengeResult'].to_s + " HaHaHa, take that Jigsaw!!!"
      end
      resp = make_second_request("/SearchContact.xhtml?companyId=#{id}&opCode=showCompDir", challenge_hash)
      cookies = resp['set-cookie'].to_s
      puts cookies
      if resp['set-cookie'].to_s.include? "BotMitigationCookie"
        puts "W00t! Golden Ticket = " + resp['set-cookie'].to_s
        cookies = resp['set-cookie'].to_s
        cookies = get_remaining_cookies("/SearchContact.xhtml?companyId=#{id}&opCode=showCompDir", cookies)
        puts cookies
      else
        puts "Something went wrong, could not break challenge. try agian maybe o.0"
        exit!
      end
      return true
    rescue
      return nil
    end
  end

  # This third request method isn't required but it grabs JSESSIONID cookie
  # and jigsaw_id cookie.  My thoughts are the moving forward they will also check for those values
  # as "proof" of a legitemit user browsing.
  # @param url [STRING] The url to make the HTTP request
  # @param cookies [HASH] Hash used to set cookies in HTTP header
  def get_remaining_cookies(url, cookies)
    headers = {
      "Host" => 'www.jigsaw.com',
      "User-Agent" => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0',
      "Accept" => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      "Accept-Language" => 'en-US,en;g=0.5',
      "Accept-Encoding" => 'gzip, deflate',
      "Content-Type" => 'text/plain',
      "Pragma" => 'no-cache',
      "Content-Length" => '0',
      "Cache-Control" => 'no-cache',
      "Connection" => 'keep-alive',
      "DNT" => '1',
      "Cookie" => cookies.to_s
    }
    http = Net::HTTP.new('www.jigsaw.com', 80)
    resp, data = http.get(url, headers)
    newcookies << ", " + resp['set-cookie'].to_s
    return newcookies
  end

  def parse_challenge_request(page)
    top = page.split('<script>')[1].split("\r\n")
    challenge = top[1].split(';')[0].split('=')[1]
    challenge_id = top[2].split(';')[0].split('=')[1]
    return {'Challenge' => challenge, 'ChallengeId' => challenge_id, 'ChallengeResult' => get_challenge_answer(challenge)}
  end

  # Jigsaw's math to prove I am not a bot hehehehehehehe
  # Silly Jigsaw =P
  def get_challenge_answer(var1)
    string = "" + var1
    array = string.split("")
    array = array.reverse
    last_digit = array[0].to_i
    array = array.sort
    min_digit = array[0].to_i
    subvar1 = (2 * array[2].to_i) + (array[1].to_i)
    subvar2 = (2 * array[2].to_i).to_s + array[1]
    power = ((array[0].to_i * 1) + 2) ** array[1].to_i
    x = (var1.to_i * 3 + subvar1)
    y = Math.cos(Math::PI * subvar1)
    answer = x * y
    answer -= power
    answer += (min_digit - last_digit)
    answer = answer.floor.to_s + subvar2
    return answer
  end
end

=begin
the JavaScript version of the function

function test(var1)
{
  var var_str=""+Challenge;
  var var_arr=var_str.split("");
  var LastDig=var_arr.reverse()[0];
  var minDig=var_arr.sort()[0];
  var subvar1 = (2 * (var_arr[2]))+(var_arr[1]*1);
  var subvar2 = (2 * var_arr[2])+var_arr[1];
  var my_pow=Math.pow(((var_arr[0]*1)+2),var_arr[1]);
  var x=(var1*3+subvar1)*1;
  var y=Math.cos(Math.PI*subvar2);
  var answer=x*y;
  answer-=my_pow*1;
  answer+=(minDig*1)-(LastDig*1);
  answer=answer+subvar2;
  return answer;
}
=end
