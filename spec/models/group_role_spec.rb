require 'spec_helper'
require 'cancan/matchers'

describe GroupRole do
  context :relations do
    it { should belong_to :user }
    it { should belong_to(:group).touch(true) }
  end

  context :validations do
    it { should validate_presence_of :user }
    it { should validate_presence_of :group }
    it { should validate_presence_of :role }

    let(:group) { create :group }
    let(:user) { create :user }
    it 'uniq index on user_id+group_id should work' do
      expect {
        lambda {
          group.members << user
          group.members << user
        }.should raise_error(ActiveRecord::RecordNotUnique)
      }.to change(GroupRole, :count).by 1
    end
  end

  context :invites do
    let(:group) { create :group }
    let(:user) { create :user }
    let(:user2) { create :user }

    it 'accepts pending invite after own create' do
      invite = create :group_invite, src_id: user2.id, dst_id: user.id, group_id: group.id
      invite.status.should == GroupInviteStatus::Pending
      create :group_role, group_id: group.id, user_id: user.id
      GroupInvite.last.status.should eq GroupInviteStatus::Accepted
    end

    it 'destroys invite after own create' do
      invite = create :group_invite, src_id: user2.id, dst_id: user.id, group_id: group.id
      group_role = create :group_role, group_id: group.id, user_id: user.id
      expect {
        group_role.destroy
      }.to change(GroupInvite, :count).by -1
    end
  end

  #it 'subscribes user to group thread' do
    #expect {
      #group.members << user
    #}.to change(Subscription, :count).by 1

    #user.subscribed?(group.thread).should be_true
  #end

  #it 'unsubscribes user from group thread' do
    #group.members << user

    #expect {
      #group.member_roles.where(user_id: user.id).first.destroy
    #}.to change(Subscription, :count).by -1

    #user.reload
    #user.subscribed?(group.thread).should be_false
  #end

  describe :permissions do
    let(:club) { build_stubbed :group, join_policy: join_policy }
    let(:user) { build_stubbed :user }
    subject { Ability.new user }

    describe :join do
      let(:group_role) { build :group_role, user: user, group: club }

      context :owner_invite_join do
        let(:join_policy) { :owner_invite_join }

        context :club_owner do
          let(:club) { build_stubbed :group, owner: user }
          it { should be_able_to :create, group_role }
        end

        context :common_user do
          it { should_not be_able_to :create, group_role }
        end
      end

      context :admin_invite_join do
        let(:join_policy) { :admin_invite_join }

        context :club_owner do
          let(:club) { build_stubbed :group, owner: user }
          it { should be_able_to :create, group_role }
        end

        context :common_user do
          it { should_not be_able_to :create, group_role }
        end
      end

      context :free_join_policy do
        let(:join_policy) { :free_join }

        context :common_user do
          it { should be_able_to :create, group_role }
        end

        context :guest do
          let(:user) { nil }
          it { should_not be_able_to :create, group_role }
        end
      end
    end

    describe :leave do
      let(:join_policy) { :free_join }

      context :club_member do
        let(:group_role) { build_stubbed :group_role, user: user, group: club }
        it { should be_able_to :destroy, group_role }
      end

      context :not_member do
        let(:group_role) { build_stubbed :group_role, group: club }

        context :guest do
          let(:user) { nil }
          it { should_not be_able_to :destroy, group_role }
        end

        context :common_user do
          let(:user) { nil }
          it { should_not be_able_to :destroy, group_role }
        end

        context :club_owner do
          let(:club) { build_stubbed :group, owner: user }
          it { should_not be_able_to :destroy, group_role }
        end
      end
    end
  end
end
