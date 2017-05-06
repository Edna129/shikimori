# frozen_string_literal: true

class Collection::Create < ServiceObjectBase
  pattr_initialize :params, :locale

  def call
    collection = Collection.new @params
    collection.state = Types::Collection::State[:unpublished]
    collection.locale = locale

    collection.generate_topics @locale if collection.save
    collection
  end
end
