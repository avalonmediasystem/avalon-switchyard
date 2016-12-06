# Copyright 2011-2015, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

describe 'selecting the avalon target' do
  it 'always selects the default avalon' do
    avalon_selected = Router.new.select_avalon('foo')
    expect(avalon_selected.class).to eq(Hash)
    expect(avalon_selected[:url]).not_to be_nil
    expect(avalon_selected[:api_token]).not_to be_nil
  end
end

describe 'determining if switchyard is sending an object or not' do
  it 'returns false when no push is occuring' do
    MediaObject.where(locked: true).destroy_all
    expect(Router.new.send_in_progress?).to be_falsey
  end

  it 'return true when a push is occuring' do
    m = MediaObject.new
    m.locked = true # fake an object in progress
    m.save
    expect(Router.new.send_in_progress?).to be_truthy
  end
end
