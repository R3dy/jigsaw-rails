json.array!(@contacts) do |contact|
  json.extract! contact, :id, :jigsawid, :company_id, :firstname, :lastname, :title, :city, :state, :zip
  json.url contact_url(contact, format: :json)
end
