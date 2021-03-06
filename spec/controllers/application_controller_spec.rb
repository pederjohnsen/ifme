require_relative './shared_examples'

include ActionView::Helpers::DateHelper
include ActionView::Helpers::TextHelper

AVATAR_COMPONENT_NAME = 'Avatar';

RSpec::Matchers.define :be_avatar_component do
  match do
    have_tag('script', with: { 'data-component-name': AVATAR_COMPONENT_NAME })
  end
end

describe ApplicationController do
  let(:user1) { create(:user1) }
  let(:user2) { create(:user2) }

  describe "#most_focus" do
    it_behaves_like :most_focus, :category
    it_behaves_like :most_focus, :mood
    it_behaves_like :most_focus, :strategy
  end

  describe "tag_usage" do
    it "is looking for categories tagged nowhere" do
      new_category = create(:category, user_id: user1.id)
      result = controller.tag_usage(new_category.id, 'category', user1.id)
        expect(result[0].length + result[1].length).to eq(0)
    end

    it "is looking for categories tagged in moments and strategies" do
      new_category = create(:category, user_id: user1.id)
        new_moment = create(:moment, user_id: user1.id, category: Array.new(1, new_category.id))
        new_strategy = create(:strategy, user_id: user1.id, category: Array.new(1, new_category.id))
        result = controller.tag_usage(new_category.id, 'category', user1.id)
        expect(result[0].length + result[1].length).to eq(2)
    end

    it "is looking for moods tagged nowhere" do
      new_mood = create(:mood, user_id: user1.id)
      result = controller.tag_usage(new_mood.id, 'mood', user1.id)
        expect(result.length).to eq(0)
    end

    it "is looking for moods tagged in moments" do
      new_mood = create(:mood, user_id: user1.id)
        new_moment = create(:moment, user_id: user1.id, mood: Array.new(1, new_mood.id))
        result = controller.tag_usage(new_mood.id, 'mood', user1.id)
        expect(result.length).to eq(1)
    end

    it "is looking for strategies tagged nowhere" do
      new_strategy = create(:strategy, user_id: user1.id)
      result = controller.tag_usage(new_strategy.id, 'strategy', user1.id)
        expect(result.length).to eq(0)
    end

    it "is looking for strategies tagged in moments" do
      new_strategy = create(:strategy, user_id: user1.id)
        new_moment = create(:moment, user_id: user1.id, strategy: Array.new(1, new_strategy.id))
        result = controller.tag_usage(new_strategy.id, 'strategy', user1.id)
        expect(result.length).to eq(1)
    end
  end

  describe '#get_stories' do
    let(:user_id) { user1.id }
    let(:moment) { create(:moment, user_id: user_id) }
    let(:strategy) { create(:strategy, user_id: user_id) }

    before { sign_in user1 }

    context 'when not including allies' do
      subject { controller.get_stories(user1, false) }

      context 'when there are no stories' do
        it { is_expected.to be_empty }
      end

      context 'when there is a moment' do
        before { moment }
        it { is_expected.to eq([moment]) }
      end

      context 'when there is a strategy' do
        before { strategy }
        it { is_expected.to eq([strategy]) }
      end

      context 'when there are moments and strategies' do
        before { moment; strategy }
        it { is_expected.to include(moment, strategy) }
      end
    end

    context 'when including allies' do
      let(:ally_id) { user2.id }
      let!(:allyship) { create(:allyships_accepted, user_id: user_id, ally_id: ally_id) }
      let(:viewers) { [user_id] }
      let(:timestamp) { Time.now }
      let(:ally_moment) do
        create(:moment, user_id: ally_id, viewers: viewers, published_at: timestamp)
      end
      let(:ally_strategy) do
        create(:strategy, user_id: ally_id, viewers: viewers, published_at: timestamp)
      end

      subject { controller.get_stories(user1, true) }

      context 'when there are no stories' do
        it { is_expected.to be_empty }
      end

      context 'when there are stories' do
        before do
            moment
            strategy
            ally_moment
            ally_strategy
          end

        context 'when ally stories are published' do
          it { is_expected.to include(moment, strategy, ally_moment, ally_strategy) }
        end

        context 'when ally stories are drafts' do
          let(:timestamp) { nil }
          it { is_expected.to include(moment, strategy) }
          it { is_expected.not_to include(ally_moment, ally_strategy) }
        end

        context 'when ally stories do not include user in viewers' do
          let(:viewers) { nil }
          it { is_expected.to include(moment, strategy) }
          it { is_expected.not_to include(ally_moment, ally_strategy) }
        end
      end
    end
  end

  describe "moments_stats" do
    before(:example) do
      sign_in user1
    end
    it "has no moments" do
        expect(controller.moments_stats).to eq('')
    end

    it "has one moment" do
      new_moment = create(:moment, user_id: user1.id)
      expect(controller.moments_stats).to eq('')
    end

    it "has more than one moment created this month" do
      new_moment1 = create(:moment, user_id: user1.id)
      new_moment2 = create(:moment, user_id: user1.id)
      expect(controller.moments_stats).to eq('<div class="center" id="stats">You have written a <strong>total</strong> of <strong>2</strong> moments.</div>')
    end

    it "has more than one moment created on different months" do
      new_moment1 = create(:moment, user_id: user1.id, created_at: '2014-01-01 00:00:00')
      new_moment2 = create(:moment, user_id: user1.id)

      expect(controller.moments_stats).to eq('<div class="center" id="stats">You have written a <strong>total</strong> of <strong>2</strong> moments. This <strong>month</strong> you wrote <strong>1</strong> moment.</div>')

      new_moment3 = create(:moment, user_id: user1.id)

      expect(controller.moments_stats).to eq('<div class="center" id="stats">You have written a <strong>total</strong> of <strong>3</strong> moments. This <strong>month</strong> you wrote <strong>2</strong> moments.</div>')
    end
  end

  describe 'generate_comment' do
    let(:user3) { create(:user3) }
    let(:comment) { 'Hello from the outside'}

    def delete_comment(comment_id)
      %(<div class="delete_comment"><a id="delete_comment_#{comment_id}" class="delete_comment_button" href=""><i class="fa fa-times"></i></a></div>)
    end

    def comment_info(user)
      %(<a href="/profile?uid=#{controller.get_uid(user.id)}">#{user.name}</a> - less than a minute ago)
    end

    before do
      create(:allyships_accepted, user_id: user1.id, ally_id: user2.id)
      create(:allyships_accepted, user_id: user1.id, ally_id: user3.id)
    end

    context 'Moments' do
      let(:new_moment) { create(:moment, user_id: user1.id, viewers: [user2.id, user3.id]) }

      context 'Comment posted by Moment creator who is logged in' do
        before(:each) do
          sign_in user1
        end

        it 'generates a valid comment object when visbility is all' do
          new_comment = create(:comment, comment: comment, commentable_type: 'moment', commentable_id: new_moment.id, comment_by: user1.id, visibility: 'all')
          expect(controller.generate_comment(new_comment, 'moment')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user1),
            comment_text: comment,
            visibility: nil,
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end

        it 'generates a valid comment object when visbility is private' do
          new_comment = create(:comment, comment: comment, commentable_type: 'moment', commentable_id: new_moment.id, comment_by: user1.id, visibility: 'private', viewers: [user2.id])
          expect(controller.generate_comment(new_comment, 'moment')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user1),
            comment_text: comment,
            visibility: "Visible only between you and #{user2.name}",
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end
      end

      context 'Comment posted by Moment viewer who is logged in' do
        before(:each) do
          sign_in user2
        end

        it 'generates a valid comment object when visbility is all' do
          new_comment = create(:comment, comment: comment, commentable_type: 'moment', commentable_id: new_moment.id, comment_by: user2.id, visibility: 'all')
          expect(controller.generate_comment(new_comment, 'moment')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user2),
            comment_text: comment,
            visibility: nil,
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end

        it 'generates a valid comment object when visbility is private' do
          new_comment = create(:comment, comment: comment, commentable_type: 'moment', commentable_id: new_moment.id, comment_by: user2.id, visibility: 'private', viewers: [user1.id])
          expect(controller.generate_comment(new_comment, 'moment')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user2),
            comment_text: comment,
            visibility: "Visible only between you and #{user1.name}",
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end
      end
    end

    context 'Strategies' do
      let(:new_strategy) { create(:strategy, user_id: user1.id, viewers: [user2.id, user3.id]) }

      context 'Comment posted by Strategy creator who is logged in' do
        before(:each) do
          sign_in user1
        end

        it 'generates a valid comment object when visbility is all' do
          new_comment = create(:comment, comment: comment, commentable_type: 'strategy', commentable_id: new_strategy.id, comment_by: user1.id, visibility: 'all')
          expect(controller.generate_comment(new_comment, 'strategy')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user1),
            comment_text: comment,
            visibility: nil,
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end

        it 'generates a valid comment object when visbility is private' do
          new_comment = create(:comment, comment: comment, commentable_type: 'strategy', commentable_id: new_strategy.id, comment_by: user1.id, visibility: 'private', viewers: [user2.id])
          expect(controller.generate_comment(new_comment, 'strategy')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user1),
            comment_text: comment,
            visibility: "Visible only between you and #{user2.name}",
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end
      end

      context 'Comment posted by Strategy viewer who is logged in' do
        before(:each) do
          sign_in user2
        end

        it 'generates a valid comment object when visbility is all' do
          new_comment = create(:comment, comment: comment, commentable_type: 'strategy', commentable_id: new_strategy.id, comment_by: user2.id, visibility: 'all')
          expect(controller.generate_comment(new_comment, 'strategy')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user2),
            comment_text: comment,
            visibility: nil,
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end

        it 'generates a valid comment object when visbility is private' do
          new_comment = create(:comment, comment: comment, commentable_type: 'strategy', commentable_id: new_strategy.id, comment_by: user2.id, visibility: 'private', viewers: [user1.id])
          expect(controller.generate_comment(new_comment, 'strategy')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user2),
            comment_text: comment,
            visibility: "Visible only between you and #{user1.name}",
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end
      end
    end

    context 'Meetings' do
      let(:new_meeting) { create :meeting }

      before do
        create :meeting_member, user_id: user1.id, leader: true, meeting_id: new_meeting.id
        create :meeting_member, user_id: user2.id, leader: false, meeting_id: new_meeting.id
      end

      context 'Comment posted by Meeting creator who is logged in' do
        it 'generates a valid comment object' do
          sign_in user1
          new_comment = create(:comment, comment: comment, commentable_type: 'meeting', commentable_id: new_meeting.id, comment_by: user1.id, visibility: 'all')
          expect(controller.generate_comment(new_comment, 'meeting')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user1),
            comment_text: comment,
            visibility: nil,
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end
      end

      context 'Comment posted by Meeting member who is logged in' do
        it 'generates a valid comment object' do
          sign_in user2
          new_comment = create(:comment, comment: comment, commentable_type: 'meeting', commentable_id: new_meeting.id, comment_by: user2.id, visibility: 'all')
          expect(controller.generate_comment(new_comment, 'meeting')).to include(
            commentid: new_comment.id,
            :profile_picture => be_avatar_component,
            comment_info: comment_info(user2),
            comment_text: comment,
            visibility: nil,
            delete_comment: delete_comment(new_comment.id),
            no_save: false
          )
        end
      end
    end
  end
end
