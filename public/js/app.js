$(document).ready(function(){

    function ViewModel() {
        var self = this;

        //モデルの定義と初期値設定
        self.selectData = ko.observableArray([
            {name: "厚別区1", value: "atsu01"}
            ]);
        self.selected1 = ko.observable(self.selectData()[0]);
        self.selectedValue = ko.computed(function() {
            var value = self.selected1();
            return value;
        }, self);
        self.calDate = ko.observableArray([
            {date: "2014-01-01", type: "0"}
            ]);

        //進む・戻るボタンのパラメータ(日付)
        var d = new Date();
        self.pager = {
            prev:  d.addDays(-7).toString('yyyyMMdd'),
            today: d.toString('yyyyMMdd'),
            next:  d.addDays(7).toString('yyyyMMdd'),
        };
        //カレンダーを更新する関数
        self.updateCal = function(arrow) {
            var start = self.pager[arrow];
            var ajax_url = "/api/v0/cal/" + self.selected1().value + "?start=" + start;
            //一週間分のデータを取得
            $.ajax({
                type: "GET",
                url: ajax_url,
                dataType: "json",
                cache: false,
                success: function (data) {
                    self.pager = data.pager;
                    //取得したデータで表示を更新
                    vm.calDate(data.cal);
                }
            });
        }
    }
    var vm = new ViewModel();
    ko.applyBindings(vm);

    //最初のコンボを作成するためのデータを取得
    $.ajax({
        type: "GET",
        url: "/api/v0/addr",
        dataType: "json",
        cache: false,
        success: function (data) {
            vm.selectData(data);
        }
    });
});
