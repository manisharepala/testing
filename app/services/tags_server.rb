class TagsServer
  include HTTParty
  base_uri '13.234.165.191'
  # base_uri 'localhost:4000'
  # base_uri '13.233.76.145'
  FIND_TAG = '/tags/find_tag'

  def self.get_tag_guid(name,value)
    res = get(FIND_TAG, {query: {name: name, value:value}})
    if res.code == 200
      (JSON.parse(res.body))['guid']
    else
      nil
    end
  end

  def self.get_tag_guid_by_key(key)
    res = get(FIND_TAG, {query: {key:key}})
    if res.code == 200
      (JSON.parse(res.body))['guid']
    else
      nil
    end
  end

  def self.get_child_tags(guid)
    res = get('/tags/get_child_tags', {query: {guid:guid}})
    if res.code == 200
      JSON.parse(res.body)
    else
      {}
    end
  end

  def self.get_sibling_tags(guid)
    res = get('/tags/get_sibling_tags', {query: {guid:guid}})
    if res.code == 200
      JSON.parse(res.body)
    else
      {}
    end
  end

  def self.get_tags_by_name(name)
    res = get('/tags/get_tags_by_name', {query: {name:name}})
    if res.code == 200
      JSON.parse(res.body)
    else
      {}
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

  def self.get_tags_data(guids)
    res = get('/tags/find_tags', {query: {guids: guids}})
    if res.code == 200
      JSON.parse(res.body)
    else
      []
    end
  end

  def self.get_uniq_tag_values_with_guids
    res = get('/tags/get_uniq_tag_values_with_guids')
    if res.code == 200
      JSON.parse(res.body)
    else
      {}
    end
  end

end
