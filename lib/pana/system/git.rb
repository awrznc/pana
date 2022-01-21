module Git
  def clone(target, dir)
    return %x( git clone --quiet --single-branch #{target} #{dir} --shallow-since "2021-01-01" )
  end

  def log(project_path, author)
    return %x( git -C #{project_path} log --author="#{author}" --pretty=tformat: --numstat --since="2021-01-01" --until="2021-12-31" )
  end

  def shortlog(project_path)
    return %x( git -C #{project_path} shortlog -nse --since="2021-01-01" --until="2021-12-31" )
  end

  module_function :clone, :log, :shortlog
end
