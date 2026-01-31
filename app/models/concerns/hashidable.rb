module Hashidable
  extend ActiveSupport::Concern

  class_methods do
    def hashids
      @hashids ||= Hashids.new(hashid_salt, hashid_min_length, hashid_alphabet)
    end

    def hashid_salt
      Rails.application.credentials.hashid_salt || "#{table_name}_salt_#{Rails.env}"
    end

    def hashid_min_length
      6
    end

    def hashid_alphabet
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
    end

    def encode_id(id)
      hashids.encode(id)
    end

    def decode_id(hashid)
      hashids.decode(hashid).first
    end

    def find_by_hashid(hashid)
      return nil if hashid.blank?

      id = decode_id(hashid)
      return nil if id.nil?

      find_by(id: id)
    end

    def find_by_hashid!(hashid)
      record = find_by_hashid(hashid)
      raise ActiveRecord::RecordNotFound, "Couldn't find #{name} with hashid '#{hashid}'" unless record

      record
    end
  end

  def hashid
    self.class.encode_id(id)
  end

  def to_param
    hashid
  end
end
