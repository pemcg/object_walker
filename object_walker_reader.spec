%define name        object_walker_reader
%define release     1
%define version     1.8
Name:		%{name}
Version:	%{version}
Release:	%{release}
Summary:	Extract the object_walker output from automation.log

License:	MIT
URL:		https://github.com/pemcg/object_walker
Source0:	%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}
BuildArch:      noarch

%description
object_walker_reader extracts the output from object_walker and writes it out in a nicely formatted indented manner

%prep
%setup -q -c -n %{name}

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/root
install -m 0755 %{name}.rb %{buildroot}/root/%{name}.rb

%files

%defattr(-,root,root)
%attr(0755,root,root) /root/object_walker_reader.rb

%doc

%changelog

