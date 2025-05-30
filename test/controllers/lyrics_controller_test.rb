require "test_helper"

class LyricsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get lyrics_index_url
    assert_response :success
  end

  test "should get practice" do
    get lyrics_practice_url
    assert_response :success
  end

  test "should get search" do
    get lyrics_search_url
    assert_response :success
  end
end
