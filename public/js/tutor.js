$(document).ready(function(){
    var vm = function() {
        var self = this;
        self.asdf = ko.observable("fuga");
    };
    ko.applyBindings(vm);

    $('#click1').on('click', function(e) {
        console.log(this);
        console.log(vm);
        console.log(asdf);
        console.log(vm.asdf);
        asdf("hoge")
    });
});

