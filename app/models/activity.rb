class Activity < ApplicationRecord
  belongs_to :actor, polymorphic: true
  belongs_to :target, polymorphic: true, optional: true

  scope :recent, -> { order(created_at: :desc) }

  def summary
    "#{actor_display} #{action} #{target_display}"
  end

  def actor_display
    actor.try(:email) || actor.try(:name) || actor.class.name
  end

  def target_display
    target.try(:title) || target.try(:name) || target.class.name
  end
end
