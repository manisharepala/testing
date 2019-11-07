class TagsServer
  include HTTParty
  base_uri '13.234.165.191'
  # base_uri 'localhost:4000'
  # base_uri '13.233.76.145'
  FIND_TAG = '/tags/find_tag'
  # TAGS_DB_ID = '5c209b1e68ce596b0168bf33'
  #tags_db_id Learnflix = '5c209b1e68ce596b0168bf33', Cengage = '5d7623c6fdbd263418f59abc'

  def self.get_tag_guid(name,value,tags_db_id)
    res = get(FIND_TAG, {query: {name: name, value:value, tags_db_id:tags_db_id}})
    if res.code == 200
      (JSON.parse(res.body))['guid']
    else
      nil
    end
  end

  def self.get_tag_guid_by_key(key,tags_db_id)
    res = get(FIND_TAG, {query: {key:key, tags_db_id:tags_db_id}})
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

  def self.get_tags_by_name(name,tags_db_id)
    res = get('/tags/get_tags_by_name', {query: {name:name, tags_db_id:tags_db_id}})
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

  def self.get_uniq_tag_values_with_guids(tags_db_id)
    res = get('/tags/get_uniq_tag_values_with_guids', {query: {tags_db_id:tags_db_id}})
    if res.code == 200
      JSON.parse(res.body)
    else
      {}
    end
  end

end
