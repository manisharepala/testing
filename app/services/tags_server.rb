class TagsServer
  include HTTParty
  base_uri '13.233.76.145'
  FIND_TAG = '/tags/find_tag'

  def self.get_tag_guid(name,value)
    res = get(FIND_TAG, {query: {name: name, value:value}})
    if res.code == 200
      (JSON.parse(res.body))['guid']
    else
      nil
    end
  end

  def self.get_tag_data(guid)
    res = get(FIND_TAG, {query: {guid: guid}})
    if res.code == 200
      JSON.parse(res.body)
    else
      {}
    end
  end

end
