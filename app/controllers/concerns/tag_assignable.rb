module TagAssignable
  extend ActiveSupport::Concern

  private

  def assign_tags_to_record(record, tag_ids_param, workspace)
    return unless tag_ids_param.present?

    tag_ids = Array(tag_ids_param).map(&:to_i)
    valid_tags = workspace.tags.where(id: tag_ids)

    if valid_tags.count != tag_ids.uniq.count
      invalid_count = tag_ids.uniq.count - valid_tags.count
      Rails.logger.warn("#{self.class.name}: #{invalid_count} invalid tag_ids provided by user #{current_user.id} in workspace #{workspace.id}")
    end

    record.tags = valid_tags
  end
end
