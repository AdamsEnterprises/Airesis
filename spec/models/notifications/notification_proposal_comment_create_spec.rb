require 'spec_helper'
require 'requests_helper'
require 'cancan/matchers'

describe ProposalComment, type: :model, emails: true do

  it 'when a proposal comment is created sends correctly an email to authors and participants' do
    user1 = create(:user)
    group = create(:group, current_user_id: user1.id)
    proposal = create(:group_proposal, current_user_id: user1.id, group_proposals: [GroupProposal.new(group: group)])

    participants = []
    5.times do
      user = create(:user)
      participants << user
      create_participation(user, group)
    end

    create(:positive_ranking, proposal: proposal, user: participants[0])
    create(:negative_ranking, proposal: proposal, user: participants[1])

    create(:proposal_comment, proposal: proposal, user: participants[2])

    expect(NotificationProposalCommentCreate.jobs.size).to eq 1
    NotificationProposalCommentCreate.drain
    expect(Sidekiq::Extensions::DelayedMailer.jobs.size).to eq 3
    Sidekiq::Extensions::DelayedMailer.drain
    first_deliveries = ActionMailer::Base.deliveries.first(3)

    emails = first_deliveries.map { |m| m.to[0] }
    receiver_emails = [user1,participants[0],participants[1]].map(&:email)
    expect(emails).to match_array(Array.new(3,"discussion+proposal_c_#{proposal.id}@airesis.it"))
    expect(first_deliveries.map { |m| m.bcc[0] }).to match_array receiver_emails

    expect(Alert.count).to eq 3
    expect(Alert.first(3).map { |a| a.user }).to match_array [user1,participants[0],participants[1]]
  end
end