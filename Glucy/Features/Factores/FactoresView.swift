import SwiftUI

/// Las cinco cosas que más movieron la estimación, cada una con su nombre en palabras y su
/// cifra con signo.
///
/// Está a un toque de la pantalla de inicio y a propósito es la **segunda** profundidad y no
/// la primera: en inicio va la cifra y nada más, porque de madrugada no cabe una explicación.
/// Quien quiere entender por qué, entra aquí.
///
/// El color no es el único portador de la información: cada renglón lleva flecha, nombre y
/// cifra con signo, y la barra mide la contribución. La pantalla se revisa en escala de
/// grises y sigue diciendo lo mismo.
struct FactoresView: View {
    let modelo: FactoresViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.entreTarjetas) {
                cabecera
                if let explicacion = modelo.explicacion { frase(explicacion) }
                if modelo.renglones.isEmpty {
                    if let porQue = modelo.porQueNoHayNada { nota(porQue) }
                } else {
                    tarjetaDeFactores
                }
                if let desacuerdo = modelo.desacuerdo { nota(desacuerdo) }
                aviso
            }
            .padding(.horizontal, Tema.Espacio.margenLateral)
            .padding(.vertical, Tema.Espacio.entreTarjetas)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tema.Colores.fondo)
        .navigationTitle("Por qué")
    }

    /// La cifra protagonista, otra vez: quien entró aquí desde inicio tiene que seguir viendo
    /// de qué número se está hablando.
    private var cabecera: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            if let cifra = modelo.cifra {
                Text(cifra)
                    .font(.system(size: Tema.Tipografia.tamanoCifraSecundaria, weight: .bold))
                    .foregroundStyle(Tema.Colores.azulProfundo)
                    .accessibilityIdentifier("cifraDeLosFactores")
            }
            if let cuando = modelo.cuando {
                Text("Estimación \(cuando)")
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func frase(_ texto: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.unidad * 2) {
            Text(texto)
                .font(Tema.Tipografia.textoLectura)
                .foregroundStyle(Tema.Colores.textoPrincipal)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("explicacion")
            if let origen = modelo.origenDeLaFrase {
                Text(origen)
                    .font(Tema.Tipografia.etiqueta)
                    .foregroundStyle(Tema.Colores.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
    }

    private var tarjetaDeFactores: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.interior) {
            Text("Qué la movió")
                .font(Tema.Tipografia.tituloTarjeta)
                .foregroundStyle(Tema.Colores.textoPrincipal)
            ForEach(modelo.renglones) { cada in
                renglon(cada)
            }
        }
        .padding(Tema.Espacio.interior)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Colores.superficie)
        .clipShape(RoundedRectangle(cornerRadius: Tema.Radio.tarjetaGrande))
        .accessibilityIdentifier("listaDeFactores")
    }

    private func renglon(_ renglon: RenglonDeFactor) -> some View {
        let color = renglon.sube ? Tema.Colores.alertaAmbar : Tema.Colores.azulPrimario
        return VStack(alignment: .leading, spacing: Tema.Espacio.unidad) {
            HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.unidad * 2) {
                Image(systemName: renglon.sube ? "arrow.up" : "arrow.down")
                    .font(.footnote)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(renglon.nombre)
                    .font(Tema.Tipografia.textoLectura)
                    .foregroundStyle(Tema.Colores.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tema.Espacio.unidad * 2)
                Text(renglon.cifra)
                    .font(Tema.Tipografia.valorFila)
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            barra(proporcion: renglon.proporcion, color: color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(renglon.hablado)
    }

    /// La barra es decoración medida, no información nueva: la cifra de al lado ya lo dice.
    /// Por eso está oculta a VoiceOver, que lee el renglón completo de una vez.
    private func barra(proporcion: Double, color: Color) -> some View {
        GeometryReader { espacio in
            RoundedRectangle(cornerRadius: Tema.Radio.completo)
                .fill(color.opacity(0.35))
                .frame(width: max(2, espacio.size.width * proporcion))
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private func nota(_ texto: String) -> some View {
        Text(texto)
            .font(Tema.Tipografia.etiqueta)
            .foregroundStyle(Tema.Colores.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("notaDeLosFactores")
    }

    /// El aviso que va en la app y en el README, en la pantalla donde más se parece a un
    /// diagnóstico: Glucy informa, no prescribe.
    private var aviso: some View {
        Text("Glucy no es un dispositivo médico certificado. Esto es una estimación y no "
            + "sustituye una medición.")
            .font(Tema.Tipografia.etiqueta)
            .foregroundStyle(Tema.Colores.textoSecundario)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
