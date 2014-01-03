json.array!(@companies) do |company|
  json.extract! company, :id, :jigsawid, :name, :website, :overview, :headquarters, :phone, :industries, :employees, :revenue, :ownership, :contacts
  json.url company_url(company, format: :json)
end
