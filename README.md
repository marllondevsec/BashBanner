#BashBanner

BashBanner é um programa de gerenciamento dinâmico de banners para terminais Linux. Ele funciona em qualquer shell moderno compatível com Bash ou Zsh e foi desenvolvido para exibir banners visuais automaticamente ao entrar em diretórios específicos pelo terminal.

O objetivo do BashBanner é personalizar o ambiente do terminal, facilitar a identificação do diretório atual e oferecer uma experiência visual dinâmica sem interferir no funcionamento normal do sistema.

Novidades

A versão atual do BashBanner conta com detecção automática do shell do sistema, funcionando tanto em Bash quanto em Zsh sem necessidade de configuração manual. O programa possui suporte nativo a sistemas que utilizam diretórios em inglês ou português, garantindo compatibilidade total independentemente do idioma da distribuição Linux.

Foi adicionado um instalador inteligente que identifica o shell ativo, injeta apenas o código compatível e remove automaticamente trechos de código que não tenham portabilidade no sistema detectado. Também foi implementado um desinstalador universal capaz de reverter completamente todas as alterações feitas durante a instalação.

O diretório bannerstartup foi introduzido para permitir a exibição de banners sempre que o terminal é aberto, sem que o banner seja reexecutado ao entrar no diretório home.

Como o BashBanner funciona

O BashBanner funciona adicionando um bloco de código controlado ao arquivo de inicialização do shell do usuário. Em sistemas Bash, o código é inserido no arquivo .bashrc. Em sistemas Zsh, o código é inserido no arquivo .zshrc.

Esse bloco de código detecta automaticamente o diretório atual do usuário no terminal. Ao identificar a mudança de diretório, o programa verifica se existe um diretório de banners correspondente. Caso exista, um banner em formato .txt é escolhido aleatoriamente e exibido no terminal.

No Zsh, o mecanismo de detecção é feito através do hook chpwd. No Bash, a detecção é feita utilizando o PROMPT_COMMAND. Nenhum comando essencial do sistema é sobrescrito ou modificado.

Estrutura de diretórios

Após a instalação, os diretórios de banners são criados no mesmo local onde o instalador foi executado. Cada diretório representa um local comum do sistema operacional.

O diretório bannerstartup é usado para banners exibidos apenas ao abrir o terminal. Os diretórios bannerdesktop, bannerdocuments, bannerdownloads, bannerpictures, bannermusic, bannervideos, bannerpublico e bannertemplates correspondem aos diretórios padrão do usuário, como Desktop, Documentos, Downloads, Imagens, Músicas, Vídeos, Público e Modelos.

Para adicionar banners, basta colocar arquivos .txt dentro do diretório correspondente. O programa escolherá automaticamente um banner aleatório sempre que o diretório for acessado.

Compatibilidade com idiomas

O BashBanner é compatível com sistemas configurados em português ou inglês. Ele utiliza o padrão XDG para detectar os diretórios reais do usuário, como Documentos ou Documents, Músicas ou Music, Vídeos ou Videos, entre outros.

Essa detecção é automática e não exige nenhuma configuração adicional por parte do usuário.

Instalação

Após clonar o repositório, o programa pode ser instalado executando o script de instalação. O instalador detecta automaticamente o shell padrão do sistema e realiza apenas as alterações necessárias para aquele ambiente.

Após a instalação, é recomendado recarregar o shell para que as alterações tenham efeito. Isso pode ser feito fechando e abrindo o terminal ou executando o comando source no arquivo de inicialização do shell correspondente.

Banner de inicialização

O diretório bannerstartup é responsável pelos banners exibidos ao abrir o terminal. Esses banners são mostrados apenas uma vez por sessão e não são reexibidos ao navegar pelo diretório home. Isso evita poluição visual e repetição excessiva de banners.

Desinstalação

O BashBanner inclui um desinstalador universal que pode ser executado da mesma forma que o instalador. O desinstalador remove todos os diretórios criados pelo programa, restaura os arquivos de inicialização do shell a partir de backups e elimina completamente qualquer código injetado.

Caso seja necessário verificar manualmente, o código do BashBanner sempre é adicionado ao final do arquivo de inicialização do shell e pode ser removido facilmente.

Segurança e portabilidade

O BashBanner não utiliza permissões administrativas, não altera variáveis críticas do sistema, não modifica o PATH e não instala binários globais. Todas as alterações são locais ao usuário e totalmente reversíveis.

O programa foi desenvolvido com foco em portabilidade, segurança e controle total por parte do usuário.

Finalidade

O BashBanner é ideal para usuários que desejam personalizar o terminal, desenvolvedores que passam longos períodos no shell, ambientes educacionais, laboratórios ou simplesmente para quem deseja tornar o terminal mais informativo e visualmente agradável.

BashBanner oferece banners dinâmicos, portáveis e sob total controle do usuário.
