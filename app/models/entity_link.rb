# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2015 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: entity_links
#
#  created_at   :datetime         not null
#  creator_id   :integer
#  description  :text
#  entity_id    :integer          not null
#  entity_role  :string           not null
#  id           :integer          not null, primary key
#  linked_id    :integer          not null
#  linked_role  :string           not null
#  lock_version :integer          default(0), not null
#  main         :boolean          default(FALSE), not null
#  nature       :string           not null
#  post         :string
#  started_at   :datetime
#  stopped_at   :datetime
#  updated_at   :datetime         not null
#  updater_id   :integer
#

class EntityLink < Ekylibre::Record::Base
  belongs_to :entity
  belongs_to :linked, class_name: 'Entity'
  enumerize :nature, in: Nomen::EntityLinkNatures.all
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_datetime :started_at, :stopped_at, allow_blank: true, on_or_after: Time.new(1, 1, 1, 0, 0, 0, '+00:00')
  validates_inclusion_of :main, in: [true, false]
  validates_presence_of :entity, :entity_role, :linked, :linked_role, :nature
  # ]VALIDATORS]
  validates_inclusion_of :nature, in: nature.values

  selects_among_all :main, scope: :entity_id

  scope :of_entity, lambda { |entity|
    # where("stopped_at IS NULL AND ? IN (entity_id, linked_id)", entity.id)
    # where(stopped_at: nil, entity.id => [:entity_id, :linked_id])
    where(stopped_at: nil).where('? IN (entity_id, linked_id)', entity.id)
  }
  scope :at, lambda { |at|
    where(arel_table[:started_at].eq(nil).or(arel_table[:started_at].lt(at)).and(arel_table[:stopped_at].eq(nil).or(arel_table[:stopped_at].gt(at))))
  }
  scope :actives, -> { at(Time.now) }

  scope :of_nature, lambda { |*natures|
    where(nature: natures.collect { |v| Nomen::EntityLinkNatures.all(v.to_sym) }.flatten.map(&:to_s).uniq)
  }

  before_validation do
    self.started_at ||= Time.now
    if item = Nomen::EntityLinkNatures[nature]
      self.entity_role = item.entity
      self.linked_role = item.linked
    end
  end
end
